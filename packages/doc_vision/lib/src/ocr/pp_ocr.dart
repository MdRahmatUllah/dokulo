import 'dart:math' as math;
import 'dart:typed_data';

/// An image for OCR: 8-bit BGR, row by row (what the PP-OCR models expect).
class Raster {
  Raster(this.width, this.height, this.bgr)
    : assert(bgr.length == width * height * 3);

  /// From BGRA pixels (PdfEngine.render, camera frames).
  factory Raster.fromBgra(int width, int height, Uint8List bgra) {
    final bgr = Uint8List(width * height * 3);
    for (var i = 0, j = 0; i < bgra.length; i += 4, j += 3) {
      bgr[j] = bgra[i];
      bgr[j + 1] = bgra[i + 1];
      bgr[j + 2] = bgra[i + 2];
    }
    return Raster(width, height, bgr);
  }

  /// From 8-bit grey (a scan).
  factory Raster.fromGrey(int width, int height, Uint8List grey) {
    final bgr = Uint8List(width * height * 3);
    for (var i = 0; i < grey.length; i++) {
      bgr[i * 3] = bgr[i * 3 + 1] = bgr[i * 3 + 2] = grey[i];
    }
    return Raster(width, height, bgr);
  }

  final int width, height;
  final Uint8List bgr;
}

/// A box in raster pixels, origin top-left.
typedef PixelBox = ({int left, int top, int right, int bottom});

/// A detected text line: a rotated rectangle in image pixels. Scans are a
/// little skewed, and an axis-aligned box around a tilted line takes in the
/// lines above and below (PaddleOCR takes minAreaRect for the same reason).
class TextQuad {
  const TextQuad(this.cx, this.cy, this.angle, this.length, this.height);
  final double cx, cy;

  /// Of the long side, in radians.
  final double angle;
  final double length, height;

  /// The axis-aligned bounds, clamped to [maxX] × [maxY].
  PixelBox bounds(int maxX, int maxY) {
    final c = math.cos(angle).abs(), s = math.sin(angle).abs();
    final dx = (c * length + s * height) / 2,
        dy = (s * length + c * height) / 2;
    return (
      left: math.max(0, (cx - dx).floor()),
      top: math.max(0, (cy - dy).floor()),
      right: math.min(maxX, (cx + dx).ceil()),
      bottom: math.min(maxY, (cy + dy).ceil()),
    );
  }
}

/// One recognised line of text.
class OcrLine {
  const OcrLine(this.text, this.box, this.confidence);
  final String text;
  final PixelBox box;

  /// The mean of the recogniser's per-character probabilities, 0 to 1.
  final double confidence;

  @override
  String toString() => '$text (${confidence.toStringAsFixed(2)}) $box';
}

/// Runs one ONNX model: input `x` in, its first output back.
abstract interface class OnnxRunner {
  /// [model] is `det`, `cls` or `rec`.
  Future<(Float32List, List<int>)> run(
    String model,
    Float32List input,
    List<int> shape,
  );
}

/// The PP-OCRv5 pipeline (DK-0398; Technology plan, `pp_ocr`): detection
/// (DB), angle classification, recognition (CTC) with the Latin dictionary.
/// Pure Dart around the three models; [OnnxRunner] does the inference
/// (flutter_onnxruntime in the app, on the ONNX lane).
class PpOcr {
  PpOcr(this.runner, List<String> dictionary)
    // Class 0 is the CTC blank, 1..n the dictionary, n+1 the space. Empty
    // lines are dropped: the asset ends with a newline, and the trailing ''
    // that split('\n') leaves took the space's class, so on the device no
    // word had a space (DK-1071).
    : _classes = ['', ...dictionary.where((c) => c.isNotEmpty), ' '];

  final OnnxRunner runner;
  final List<String> _classes;

  /// The detector sees the image scaled so its longer side is at most this
  /// (an A4 page at 150 dpi passes almost unscaled; smaller text merges).
  static const detMaxSide = 1600;
  static const _detThreshold = 0.3, _boxThreshold = 0.6, _unclip = 1.5;
  static const _dropScore = 0.5, _recHeight = 48, _clsWidth = 192, _batch = 6;

  /// The lines of text in [image], top to bottom, left to right.
  Future<List<OcrLine>> recognize(Raster image) async {
    final quads = await detect(image);
    if (quads.isEmpty) return const [];
    var crops = [for (final q in quads) _crop(image, q)];
    crops = await _uprightAll(crops);
    final lines = <OcrLine>[];
    final texts = await _recognizeAll(crops);
    for (var i = 0; i < quads.length; i++) {
      final (text, confidence) = texts[i];
      if (text.trim().isNotEmpty && confidence >= _dropScore) {
        final box = quads[i].bounds(image.width, image.height);
        lines.add(OcrLine(text.trim(), box, confidence));
      }
    }
    return lines;
  }

  /// How far a scan is turned: the clockwise quarter turns that set its
  /// text upright, or null when it has too little text to tell (Rotate PDF's
  /// "N pages look sideways", DK-1102). Lines on a sideways page are taller
  /// than wide, so it's turned a quarter and looked at again; the line
  /// classifier then tells upright from upside down by majority.
  Future<int?> orientation(Raster image) async {
    var quads = await detect(image);
    if (quads.length < 2) return null;
    var wide = 0, tall = 0;
    for (final q in quads) {
      final b = q.bounds(image.width, image.height);
      final w = b.right - b.left, h = b.bottom - b.top;
      if (w > 2 * h) wide++;
      if (h > 2 * w) tall++;
    }
    var turns = 0;
    var page = image;
    if (tall > wide) {
      page = _rotate90(image);
      turns = 1;
      quads = await detect(page);
      if (quads.length < 2) return null;
    }
    // The widest lines say it best.
    final lines = [for (final q in quads) _crop(page, q)]
      ..sort((a, b) => (b.width / b.height).compareTo(a.width / a.height));
    final sample = lines.take(_batch).toList();
    final input = Float32List(sample.length * 3 * _recHeight * _clsWidth);
    for (final (j, crop) in sample.indexed) {
      _writeLine(crop, input, j * 3 * _recHeight * _clsWidth, _clsWidth);
    }
    final (probs, _) = await runner.run('cls', input, [
      sample.length,
      3,
      _recHeight,
      _clsWidth,
    ]);
    var flipped = 0;
    for (var j = 0; j < sample.length; j++) {
      if (probs[j * 2 + 1] > 0.5) flipped++;
    }
    if (flipped * 2 > sample.length) turns += 2;
    return turns % 4;
  }

  /// The text lines in [image] (DB post-processing on the probability map).
  Future<List<TextQuad>> detect(Raster image) async {
    final scale = math.min(
      1.0,
      detMaxSide / math.max(image.width, image.height),
    );
    final w = math.max(32, (image.width * scale / 32).round() * 32);
    final h = math.max(32, (image.height * scale / 32).round() * 32);
    final input = _tensor(
      image,
      w,
      h,
      const [0.485, 0.456, 0.406],
      const [0.229, 0.224, 0.225],
    );
    final (map, shape) = await runner.run('det', input, [1, 3, h, w]);
    return linesFromProbability(
      map,
      shape[3],
      shape[2],
      scaleX: image.width / shape[3],
      scaleY: image.height / shape[2],
    );
  }

  /// DB post-processing: threshold the map, take each connected region
  /// whose mean probability is high enough, fit a rotated rectangle to it
  /// (the principal axes of its pixels), grow it by the unclip distance and
  /// scale it to the image. Reading order: by line, then by x.
  static List<TextQuad> linesFromProbability(
    Float32List map,
    int width,
    int height, {
    double scaleX = 1,
    double scaleY = 1,
  }) {
    final seen = Uint8List(width * height);
    final quads = <TextQuad>[];
    final stack = <int>[];
    final pixels = <int>[];
    for (var start = 0; start < map.length; start++) {
      if (seen[start] == 1 || map[start] <= _detThreshold) continue;
      pixels.clear();
      var sum = 0.0;
      stack.add(start);
      seen[start] = 1;
      while (stack.isNotEmpty) {
        final p = stack.removeLast();
        pixels.add(p);
        sum += map[p];
        final x = p % width, y = p ~/ width;
        for (final q in [
          if (x > 0) p - 1,
          if (x < width - 1) p + 1,
          if (y > 0) p - width,
          if (y < height - 1) p + width,
        ]) {
          if (seen[q] == 0 && map[q] > _detThreshold) {
            seen[q] = 1;
            stack.add(q);
          }
        }
      }
      if (pixels.length < 9 || sum / pixels.length < _boxThreshold) continue;
      final quad = _fit(pixels, width, scaleX, scaleY);
      if (quad != null) quads.add(quad);
    }
    quads.sort((a, b) {
      if ((a.cy - b.cy).abs() > a.height / 2) return a.cy.compareTo(b.cy);
      return a.cx.compareTo(b.cx);
    });
    return quads;
  }

  /// The unclipped rotated rectangle around a region's pixels, or null if
  /// it is thinner than 3 map pixels.
  static TextQuad? _fit(
    List<int> pixels,
    int width,
    double scaleX,
    double scaleY,
  ) {
    double px(int p) => (p % width + 0.5) * scaleX;
    double py(int p) => (p ~/ width + 0.5) * scaleY;
    var mx = 0.0, my = 0.0;
    for (final p in pixels) {
      mx += px(p);
      my += py(p);
    }
    mx /= pixels.length;
    my /= pixels.length;
    var sxx = 0.0, syy = 0.0, sxy = 0.0;
    for (final p in pixels) {
      final dx = px(p) - mx, dy = py(p) - my;
      sxx += dx * dx;
      syy += dy * dy;
      sxy += dx * dy;
    }
    final angle = 0.5 * math.atan2(2 * sxy, sxx - syy);
    final ux = math.cos(angle), uy = math.sin(angle);
    var minU = double.infinity, maxU = -double.infinity;
    var minV = double.infinity, maxV = -double.infinity;
    for (final p in pixels) {
      final dx = px(p) - mx, dy = py(p) - my;
      final u = dx * ux + dy * uy, v = -dx * uy + dy * ux;
      minU = math.min(minU, u);
      maxU = math.max(maxU, u);
      minV = math.min(minV, v);
      maxV = math.max(maxV, v);
    }
    final length = maxU - minU + scaleX, thickness = maxV - minV + scaleY;
    if (math.min(length / scaleX, thickness / scaleY) < 3) return null;
    final d = length * thickness * _unclip / (2 * (length + thickness));
    final cu = (maxU + minU) / 2, cv = (maxV + minV) / 2;
    return TextQuad(
      mx + cu * ux - cv * uy,
      my + cu * uy + cv * ux,
      angle,
      length + 2 * d,
      thickness + 2 * d,
    );
  }

  /// Turns upside-down lines (the classifier says 180° with > 0.9).
  Future<List<Raster>> _uprightAll(List<Raster> crops) async {
    final out = [...crops];
    for (var i = 0; i < crops.length; i += _batch) {
      final batch = crops.sublist(i, math.min(i + _batch, crops.length));
      final input = Float32List(batch.length * 3 * _recHeight * _clsWidth);
      for (final (j, crop) in batch.indexed) {
        _writeLine(crop, input, j * 3 * _recHeight * _clsWidth, _clsWidth);
      }
      final (probs, _) = await runner.run('cls', input, [
        batch.length,
        3,
        _recHeight,
        _clsWidth,
      ]);
      for (var j = 0; j < batch.length; j++) {
        if (probs[j * 2 + 1] > 0.9) out[i + j] = _rotate180(batch[j]);
      }
    }
    return out;
  }

  /// Text and confidence per crop, recognised in batches of similar width.
  Future<List<(String, double)>> _recognizeAll(List<Raster> crops) async {
    final results = List<(String, double)>.filled(crops.length, ('', 0));
    final order = [for (var i = 0; i < crops.length; i++) i]
      ..sort(
        (a, b) => (crops[a].width / crops[a].height).compareTo(
          crops[b].width / crops[b].height,
        ),
      );
    for (var i = 0; i < order.length; i += _batch) {
      final batch = order.sublist(i, math.min(i + _batch, order.length));
      final maxRatio = batch
          .map((k) => crops[k].width / crops[k].height)
          .reduce(math.max);
      final width = (_recHeight * math.max(320 / _recHeight, maxRatio)).ceil();
      final input = Float32List(batch.length * 3 * _recHeight * width);
      for (final (j, k) in batch.indexed) {
        _writeLine(crops[k], input, j * 3 * _recHeight * width, width);
      }
      final (probs, shape) = await runner.run('rec', input, [
        batch.length,
        3,
        _recHeight,
        width,
      ]);
      for (final (j, k) in batch.indexed) {
        // A crop pixel x is at input x · w / crop.width (_writeLine), and a
        // step covers width / steps input pixels.
        final crop = crops[k];
        final w = math.min(
          width,
          (_recHeight * crop.width / crop.height).ceil(),
        );
        final steps = shape[1];
        results[k] = decodeCtc(
          probs,
          steps,
          shape[2],
          j,
          wordGaps: [
            for (final x in wordGaps(crop)) x * w / crop.width * steps / width,
          ],
        );
      }
    }
    return results;
  }

  /// Greedy CTC: the best class per step, repeats and blanks dropped.
  ///
  /// The model sometimes reads a narrow word gap as blanks only
  /// ("Musterstraße12", DK-1109): [wordGaps] are the steps where the line's
  /// image has a word-wide gap ([PpOcr.wordGaps]); one that falls between
  /// two characters the model wrote together puts the space in.
  (String, double) decodeCtc(
    Float32List probs,
    int steps,
    int classes,
    int item, {
    List<double> wordGaps = const [],
  }) {
    final chars = <String>[];
    final starts = <int>[], ends = <int>[];
    var sum = 0.0, kept = 0, previous = -1;
    for (var t = 0; t < steps; t++) {
      final base = (item * steps + t) * classes;
      var best = 0;
      for (var c = 1; c < classes; c++) {
        if (probs[base + c] > probs[base + best]) best = c;
      }
      if (best != 0 && best < _classes.length) {
        if (best != previous) {
          chars.add(_classes[best]);
          starts.add(t);
          ends.add(t);
          sum += probs[base + best];
          kept++;
        } else {
          ends.last = t;
        }
      }
      previous = best;
    }
    final text = StringBuffer();
    for (final (i, char) in chars.indexed) {
      if (i > 0 &&
          char != ' ' &&
          chars[i - 1] != ' ' &&
          // Next to a letter only: tabular digits leave a wide blank beside
          // a 1 ("12", "01.09"), and the model writes the spaces between
          // digit groups itself (an IBAN).
          (_letter.hasMatch(char) || _letter.hasMatch(chars[i - 1])) &&
          wordGaps.any((g) => g > ends[i - 1] && g < starts[i])) {
        text.write(' ');
      }
      text.write(char);
    }
    return (text.toString(), kept == 0 ? 0 : sum / kept);
  }

  static final _letter = RegExp(r'^\p{L}$', unicode: true);

  /// The centres (crop pixels) of the gaps between words in a line [crop]:
  /// runs of columns without ink, between the first ink and the last, at
  /// least [wordGapShare] of the line's height wide. Letters sit a few
  /// pixels apart; a space is several times wider.
  static List<double> wordGaps(Raster crop) {
    final w = crop.width, h = crop.height;
    if (w < 2 || h < 2) return const [];
    double grey(int x, int y) {
      final i = (y * w + x) * 3;
      return (crop.bgr[i] + crop.bgr[i + 1] + crop.bgr[i + 2]) / 3;
    }

    var lo = 255.0, hi = 0.0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final g = grey(x, y);
        if (g < lo) lo = g;
        if (g > hi) hi = g;
      }
    }
    if (hi - lo < 40) return const []; // no contrast: nothing to tell
    final ink = (lo + hi) / 2;
    final top = (h * 0.15).floor(), bottom = (h * 0.85).ceil();
    final empty = [
      for (var x = 0; x < w; x++)
        () {
          for (var y = top; y < bottom; y++) {
            if (grey(x, y) < ink) return false;
          }
          return true;
        }(),
    ];
    final first = empty.indexOf(false), last = empty.lastIndexOf(false);
    if (first < 0) return const [];
    final gaps = <double>[];
    var run = -1;
    for (var x = first; x <= last; x++) {
      if (empty[x]) {
        if (run < 0) run = x;
      } else if (run >= 0) {
        if (x - run >= h * wordGapShare) gaps.add((run + x - 1) / 2);
        run = -1;
      }
    }
    return gaps;
  }

  /// A run of blank columns at least this share of the line's height wide
  /// is a gap between words.
  static const wordGapShare = 0.15;

  /// [image] resized to w × h into an NCHW tensor, (x/255 - mean) / std.
  static Float32List _tensor(
    Raster image,
    int w,
    int h,
    List<double> mean,
    List<double> std,
  ) {
    final out = Float32List(3 * w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        for (var c = 0; c < 3; c++) {
          final v = _sample(
            image,
            (x + 0.5) * image.width / w - 0.5,
            (y + 0.5) * image.height / h - 0.5,
            c,
          );
          out[c * w * h + y * w + x] = (v / 255 - mean[c]) / std[c];
        }
      }
    }
    return out;
  }

  /// A text line scaled to the recogniser's height (keeping its aspect,
  /// at most [width] wide), normalised to [-1, 1], zero-padded on the right.
  static void _writeLine(Raster crop, Float32List out, int offset, int width) {
    final w = math.min(width, (_recHeight * crop.width / crop.height).ceil());
    final plane = _recHeight * width;
    for (var y = 0; y < _recHeight; y++) {
      for (var x = 0; x < w; x++) {
        for (var c = 0; c < 3; c++) {
          final v = _sample(
            crop,
            (x + 0.5) * crop.width / w - 0.5,
            (y + 0.5) * crop.height / _recHeight - 0.5,
            c,
          );
          out[offset + c * plane + y * width + x] = (v / 255 - 0.5) / 0.5;
        }
      }
    }
  }

  /// Bilinear sample of channel [c] at (x, y), edges clamped.
  static double _sample(Raster img, double x, double y, int c) {
    final x0 = x.floor().clamp(0, img.width - 1),
        y0 = y.floor().clamp(0, img.height - 1);
    final x1 = math.min(x0 + 1, img.width - 1),
        y1 = math.min(y0 + 1, img.height - 1);
    final fx = (x - x0).clamp(0.0, 1.0), fy = (y - y0).clamp(0.0, 1.0);
    double px(int xx, int yy) =>
        img.bgr[(yy * img.width + xx) * 3 + c].toDouble();
    return (px(x0, y0) * (1 - fx) + px(x1, y0) * fx) * (1 - fy) +
        (px(x0, y1) * (1 - fx) + px(x1, y1) * fx) * fy;
  }

  /// The line [q] of [image], sampled upright (deskewed) with its long side
  /// horizontal; a vertical line comes out turned.
  static Raster _crop(Raster image, TextQuad q) {
    final w = math.max(1, q.length.ceil()), h = math.max(1, q.height.ceil());
    final ux = math.cos(q.angle), uy = math.sin(q.angle);
    final out = Uint8List(w * h * 3);
    for (var j = 0; j < h; j++) {
      for (var i = 0; i < w; i++) {
        final a = i + 0.5 - w / 2, b = j + 0.5 - h / 2;
        final sx = q.cx + a * ux - b * uy - 0.5;
        final sy = q.cy + a * uy + b * ux - 0.5;
        for (var c = 0; c < 3; c++) {
          out[(j * w + i) * 3 + c] = _sample(
            image,
            sx,
            sy,
            c,
          ).round().clamp(0, 255);
        }
      }
    }
    return Raster(w, h, out);
  }

  /// [img] turned a quarter clockwise.
  static Raster _rotate90(Raster img) {
    final w = img.height, h = img.width;
    final out = Uint8List(img.bgr.length);
    for (var y = 0; y < img.height; y++) {
      for (var x = 0; x < img.width; x++) {
        final to = (x * w + (img.height - 1 - y)) * 3;
        out.setRange(to, to + 3, img.bgr, (y * img.width + x) * 3);
      }
    }
    return Raster(w, h, out);
  }

  static Raster _rotate180(Raster img) {
    final out = Uint8List(img.bgr.length);
    final n = img.width * img.height;
    for (var i = 0; i < n; i++) {
      out.setRange((n - 1 - i) * 3, (n - i) * 3, img.bgr, i * 3);
    }
    return Raster(img.width, img.height, out);
  }
}
