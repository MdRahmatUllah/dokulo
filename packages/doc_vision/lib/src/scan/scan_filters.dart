import 'dart:isolate';
import 'dart:typed_data';

import 'package:opencv_dart/opencv_dart.dart' as cv;

import 'quad_detector.dart';

/// The scanner's page filters (DK-0339; UI spec S2 filter strip). The same
/// OpenCV code runs on Android and iOS.
enum ScanFilter {
  /// The photo as taken (after the crop).
  original,

  /// Colour boost: CLAHE on the lightness channel only, so colours stay true.
  autoColour,

  /// Greyscale.
  greyscale,

  /// Black and white: an adaptive threshold, so uneven light stays readable.
  blackWhite,

  /// Shadow removal: divide each channel by its background (dilate + median
  /// blur), which flattens shadows and paper tint to white.
  removeShadows,
}

/// The size of a filter-strip preview (UI spec S2: 64 × 80).
const previewSize = (64, 80);

/// Applies [filter] to a BGR [src], then [brightness] and [contrast] (each
/// -1…1, 0 = unchanged). Returns a new Mat the caller disposes. Call it off
/// the UI isolate ([filterImage] does).
cv.Mat applyScanFilter(
  cv.Mat src,
  ScanFilter filter, {
  double brightness = 0,
  double contrast = 0,
}) {
  final out = switch (filter) {
    ScanFilter.original => src.clone(),
    ScanFilter.greyscale => cv.cvtColor(src, cv.COLOR_BGR2GRAY),
    ScanFilter.blackWhite => _blackWhite(src),
    ScanFilter.autoColour => _autoColour(src),
    ScanFilter.removeShadows => _removeShadows(src),
  };
  if (brightness == 0 && contrast == 0) return out;
  // ponytail: a linear alpha/beta; a tone curve if users ask for finer control.
  final adjusted = cv.convertScaleAbs(
    out,
    alpha: 1 + contrast.clamp(-1, 1),
    beta: 100 * brightness.clamp(-1, 1),
  );
  out.dispose();
  return adjusted;
}

cv.Mat _blackWhite(cv.Mat src) {
  final grey = cv.cvtColor(src, cv.COLOR_BGR2GRAY);
  // A block of about 1/40 of the short side (odd, at least 15 px) follows
  // the light across the page without eating thin strokes.
  final short = src.rows < src.cols ? src.rows : src.cols;
  var block = (short / 40).round() | 1;
  if (block < 15) block = 15;
  final out = cv.adaptiveThreshold(
    grey,
    255,
    cv.ADAPTIVE_THRESH_GAUSSIAN_C,
    cv.THRESH_BINARY,
    block,
    10,
  );
  grey.dispose();
  return out;
}

cv.Mat _autoColour(cv.Mat src) {
  final lab = cv.cvtColor(src, cv.COLOR_BGR2Lab);
  final channels = cv.split(lab);
  final clahe = cv.createCLAHE(clipLimit: 2, tileGridSize: (8, 8));
  final lightness = clahe.apply(channels[0]);
  final merged = cv.merge(
    cv.VecMat.fromList([lightness, channels[1], channels[2]]),
  );
  final out = cv.cvtColor(merged, cv.COLOR_Lab2BGR);
  for (final m in [lab, lightness, merged, ...channels]) {
    m.dispose();
  }
  clahe.dispose();
  return out;
}

cv.Mat _removeShadows(cv.Mat src) {
  final kernel = cv.getStructuringElement(cv.MORPH_RECT, (7, 7));
  final channels = cv.split(src);
  final flat = <cv.Mat>[];
  for (final c in channels) {
    // The background: text dilated away, then smoothed.
    final dilated = cv.dilate(c, kernel);
    final background = cv.medianBlur(dilated, 21);
    flat.add(cv.divide(c, background, scale: 255));
    dilated.dispose();
    background.dispose();
  }
  final out = cv.merge(cv.VecMat.fromList(flat));
  for (final m in [kernel, ...channels, ...flat]) {
    m.dispose();
  }
  return out;
}

/// Decodes [encoded] (JPEG or PNG), applies [filter] and encodes the result
/// as [ext] (`.jpg` or `.png`), on its own isolate. With [fit], the page is
/// first scaled down to fit inside it (the filter strip's [previewSize]);
/// without it, the full resolution is kept (saving).
Future<Uint8List> filterImage(
  Uint8List encoded,
  ScanFilter filter, {
  (int, int)? fit,
  double brightness = 0,
  double contrast = 0,
  String ext = '.jpg',
}) => Isolate.run(
  () => filterImageSync(
    encoded,
    filter,
    fit: fit,
    brightness: brightness,
    contrast: contrast,
    ext: ext,
  ),
);

/// [filterImage] on the calling isolate (for a worker that is already off
/// the UI isolate).
Uint8List filterImageSync(
  Uint8List encoded,
  ScanFilter filter, {
  (int, int)? fit,
  double brightness = 0,
  double contrast = 0,
  String ext = '.jpg',
}) {
  var src = cv.imdecode(encoded, cv.IMREAD_COLOR);
  if (src.isEmpty) {
    src.dispose();
    throw const FormatException('not an image');
  }
  if (fit != null) {
    final scale = [
      fit.$1 / src.cols,
      fit.$2 / src.rows,
    ].reduce((a, b) => a < b ? a : b);
    if (scale < 1) {
      final small = cv.resize(src, (
        (src.cols * scale).round(),
        (src.rows * scale).round(),
      ), interpolation: cv.INTER_AREA);
      src.dispose();
      src = small;
    }
  }
  final out = applyScanFilter(
    src,
    filter,
    brightness: brightness,
    contrast: contrast,
  );
  final (ok, bytes) = cv.imencode(ext, out);
  src.dispose();
  out.dispose();
  if (!ok) throw StateError('could not encode $ext');
  return bytes;
}

/// "Clean up like a scan" (Image to PDF, UI spec §21.7: "Crop to the
/// document and improve contrast"): finds the page in a photo, warps it
/// flat and applies [ScanFilter.autoColour]. A photo with no page found
/// keeps its frame and only gets the colour fix. Returns a JPEG; turned by
/// its EXIF orientation, as OpenCV decodes it. Call it off the UI isolate.
Uint8List cleanUpImageSync(Uint8List encoded) {
  final src = cv.imdecode(encoded, cv.IMREAD_COLOR);
  if (src.isEmpty) {
    src.dispose();
    throw const FormatException('not an image');
  }
  final found = detectQuad(src);
  final page = found == null ? src : warpQuad(src, found.quad);
  final out = applyScanFilter(page, ScanFilter.autoColour);
  final (ok, bytes) = cv.imencode('.jpg', out);
  for (final m in {src, page, out}) {
    m.dispose();
  }
  if (!ok) throw StateError('could not encode .jpg');
  return bytes;
}

/// A signature from a photo of ink on paper (DK-1084, the pad's Image tab):
/// the ink found with an adaptive threshold (so uneven light doesn't
/// matter), cropped to it with a small margin, as a PNG with black ink on
/// transparency. Throws [FormatException] for something that isn't an image
/// or has no ink. Call it off the UI isolate.
Uint8List signatureFromPhotoSync(Uint8List encoded) {
  final src = cv.imdecode(encoded, cv.IMREAD_GRAYSCALE);
  if (src.isEmpty) {
    src.dispose();
    throw const FormatException('not an image');
  }
  final owned = <cv.Mat>[src];
  try {
    // Photos are large: work at most 1600 px wide, plenty for a signature.
    var grey = src;
    if (src.cols > 1600) {
      grey = cv.resize(src, (1600, (src.rows * 1600 / src.cols).round()));
      owned.add(grey);
    }
    final blurred = cv.gaussianBlur(grey, (5, 5), 0);
    owned.add(blurred);
    final ink = cv.adaptiveThreshold(
      blurred,
      255,
      cv.ADAPTIVE_THRESH_GAUSSIAN_C,
      cv.THRESH_BINARY_INV,
      31,
      15,
    );
    owned.add(ink);
    // Ink is also darker than most of the page: a shadow's edge is a local
    // step, but far lighter than ink (70 % of the page's mean brightness).
    final (_, dark) = cv.threshold(
      blurred,
      0.7 * cv.mean(blurred).val1,
      255,
      cv.THRESH_BINARY_INV,
    );
    owned.add(dark);
    cv.bitwiseAND(ink, dark, dst: ink);
    final points = cv.findNonZero(ink);
    owned.add(points);
    if (points.isEmpty) throw const FormatException('no ink');
    final vec = cv.VecPoint.fromMat(points);
    final box = cv.boundingRect(vec);
    vec.dispose();
    final margin = (0.04 * (box.width > box.height ? box.width : box.height))
        .round();
    final x = (box.x - margin).clamp(0, ink.cols - 1);
    final y = (box.y - margin).clamp(0, ink.rows - 1);
    final w = (box.x + box.width + margin).clamp(0, ink.cols) - x;
    final h = (box.y + box.height + margin).clamp(0, ink.rows) - y;
    final alpha = ink.region(cv.Rect(x, y, w, h)).clone();
    owned.add(alpha);
    final black = cv.Mat.zeros(h, w, cv.MatType.CV_8UC1);
    owned.add(black);
    final bgra = cv.merge(cv.VecMat.fromList([black, black, black, alpha]));
    owned.add(bgra);
    final (ok, png) = cv.imencode('.png', bgra);
    if (!ok) throw StateError('could not encode .png');
    return png;
  } finally {
    for (final m in owned) {
      m.dispose();
    }
  }
}
