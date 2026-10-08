import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:vision_ocr/vision_ocr.dart';

import 'flutter_onnx_runner.dart';
import 'pp_ocr.dart';

/// The OCR languages (Settings → Scanning → Text recognition language).
/// Both engines read Latin script; more languages arrive as downloads.
enum OcrLanguage { auto, german, english }

/// A recognised word. [box] is normalised to 0..1 with the origin at the top
/// left: (left, top, width, height), as Vision reports it.
typedef Word = ({
  String text,
  ({double left, double top, double width, double height}) box,
  double confidence,
});

/// Why a page's text may be incomplete ("Page 7 is too blurry").
enum PageQuality { ok, tooBlurry, lowConfidence, noText }

/// One page's OCR.
class PageOcr {
  const PageOcr(this.engine, this.words, this.quality);

  /// `vision` or `ppocr`.
  final String engine;
  final List<Word> words;
  final PageQuality quality;

  /// The words, space-separated, in reading order.
  String get text => words.map((w) => w.text).join(' ');

  double get meanConfidence => words.isEmpty
      ? 0
      : words.map((w) => w.confidence).reduce((a, b) => a + b) / words.length;
}

/// What an OCR engine on a worker isolate needs from the main isolate, the
/// only one where the app's bundled assets load (rootBundle): the dictionary,
/// and the models copied out to files.
class OcrAssets {
  const OcrAssets(this.dictionary, this.models);
  final List<String> dictionary;

  /// Model file paths by name (`det`, `cls`, `rec`).
  final Map<String, String> models;
}

/// One OCR interface over Apple Vision and PP-OCRv5 (DK-0400).
abstract interface class OcrEngine {
  String get name;

  /// The words of the image at [imagePath] (PNG or JPEG).
  Future<PageOcr> recognize(
    String imagePath, {
    OcrLanguage language = OcrLanguage.auto,
  });

  /// The words of [raster] (a rendered page): no file round trip, except
  /// where the engine needs one (Vision), written in [scratch].
  Future<PageOcr> recognizeRaster(
    Raster raster, {
    OcrLanguage language = OcrLanguage.auto,
    required Directory scratch,
  });

  /// Frees the engine's native sessions.
  Future<void> close();

  /// Loads [OcrAssets] on the main isolate: the dictionary, and the models
  /// copied once into the app's cache.
  static Future<OcrAssets> loadAssets() async {
    const base = 'packages/doc_vision/assets/ocr';
    final dir = Directory('${Directory.systemTemp.path}/dokulo_ocr');
    await dir.create(recursive: true);
    final models = <String, String>{};
    for (final MapEntry(key: name, value: file)
        in FlutterOnnxRunner.files.entries) {
      final target = File('${dir.path}/$file');
      if (!await target.exists()) {
        final data = await rootBundle.load('$base/$file');
        // Written aside and renamed, so a present file is always complete.
        final part = File('${target.path}.part');
        await part.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
        await part.rename(target.path);
      }
      models[name] = target.path;
    }
    final dictionary = (await rootBundle.loadString(
      '$base/ppocrv5_latin_dict.txt',
    )).split('\n');
    return OcrAssets(dictionary, models);
  }

  /// Apple Vision on iOS (falling back to PP-OCRv5 where Vision isn't
  /// available), PP-OCRv5 everywhere else.
  ///
  /// Give [assets] on a worker isolate (from [loadAssets] on the main one);
  /// without them it loads the bundled assets, which works on the main
  /// isolate only.
  static Future<OcrEngine> forPlatform({OcrAssets? assets}) async {
    final ppocr = PpOcrEngine(
      PpOcr(
        FlutterOnnxRunner(models: assets?.models),
        assets?.dictionary ??
            (await rootBundle.loadString(
              'packages/doc_vision/assets/ocr/ppocrv5_latin_dict.txt',
            )).split('\n'),
      ),
    );
    return Platform.isIOS ? VisionEngine(fallback: ppocr) : ppocr;
  }
}

/// A page's quality from its words and its sharpness.
PageQuality judge(List<Word> words, double sharpness) {
  if (sharpness < blurLimit) return PageQuality.tooBlurry;
  if (words.isEmpty) return PageQuality.noText;
  final mean =
      words.map((w) => w.confidence).reduce((a, b) => a + b) / words.length;
  return mean < 0.75 ? PageQuality.lowConfidence : PageQuality.ok;
}

/// Below this variance of the Laplacian (on the page scaled to 800 px) a
/// page is too blurry to trust. ponytail: one fixed limit, calibrated on the
/// test scans; per-device tuning if the device checks (DK-1053)
/// say so.
const blurLimit = 60.0;

/// The variance of the Laplacian of [image]'s grey levels, scaled so the long
/// side is at most 800 px: low for a blurred page.
double sharpness(Raster image) {
  final scale = math.min(1.0, 800 / math.max(image.width, image.height));
  final w = math.max(3, (image.width * scale).round()),
      h = math.max(3, (image.height * scale).round());
  final grey = Float64List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final sx = math.min(image.width - 1, (x / scale).floor()),
          sy = math.min(image.height - 1, (y / scale).floor());
      final i = (sy * image.width + sx) * 3;
      grey[y * w + x] =
          0.114 * image.bgr[i] +
          0.587 * image.bgr[i + 1] +
          0.299 * image.bgr[i + 2];
    }
  }
  var sum = 0.0, sumSq = 0.0, n = 0;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final lap =
          grey[i - 1] + grey[i + 1] + grey[i - w] + grey[i + w] - 4 * grey[i];
      sum += lap;
      sumSq += lap * lap;
      n++;
    }
  }
  final mean = sum / n;
  return sumSq / n - mean * mean;
}

/// PP-OCRv5 behind the interface. Its Latin model reads German and English
/// alike, so [OcrLanguage] doesn't change it.
class PpOcrEngine implements OcrEngine {
  PpOcrEngine(this.ocr);
  final PpOcr ocr;

  @override
  String get name => 'ppocr';

  @override
  Future<PageOcr> recognize(
    String imagePath, {
    OcrLanguage language = OcrLanguage.auto,
  }) async => _read(decodeRaster(await File(imagePath).readAsBytes()));

  @override
  Future<PageOcr> recognizeRaster(
    Raster raster, {
    OcrLanguage language = OcrLanguage.auto,
    required Directory scratch,
  }) => _read(raster);

  @override
  Future<void> close() async {
    if (ocr.runner case final FlutterOnnxRunner runner) await runner.close();
  }

  Future<PageOcr> _read(Raster raster) async {
    final lines = await ocr.recognize(raster);
    final words = [
      for (final line in lines) ...wordsOf(line, raster.width, raster.height),
    ];
    return PageOcr(name, words, judge(words, sharpness(raster)));
  }

  /// A line's words, each with its share of the line's box (by characters).
  static List<Word> wordsOf(OcrLine line, int width, int height) {
    final parts = line.text.split(' ').where((p) => p.isNotEmpty).toList();
    final b = line.box;
    final perChar = (b.right - b.left) / line.text.length;
    final words = <Word>[];
    var offset = 0;
    for (final part in parts) {
      final start = line.text.indexOf(part, offset);
      offset = start + part.length;
      words.add((
        text: part,
        box: (
          left: (b.left + start * perChar) / width,
          top: b.top / height,
          width: part.length * perChar / width,
          height: (b.bottom - b.top) / height,
        ),
        confidence: line.confidence,
      ));
    }
    return words;
  }
}

/// A PNG or JPEG as an OCR raster.
Raster decodeRaster(Uint8List bytes) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    throw const OcrException(OcrFailure.notAnImage); // a damaged file throws
  }
  if (decoded == null) throw const OcrException(OcrFailure.notAnImage);
  final rgb = decoded.convert(numChannels: 3, format: img.Format.uint8);
  final bgr = Uint8List(rgb.width * rgb.height * 3);
  var i = 0;
  for (final p in rgb) {
    bgr[i++] = p.b.toInt();
    bgr[i++] = p.g.toInt();
    bgr[i++] = p.r.toInt();
  }
  return Raster(rgb.width, rgb.height, bgr);
}

/// Apple Vision behind the interface; PP-OCRv5 when Vision is unavailable
/// or fails.
class VisionEngine implements OcrEngine {
  VisionEngine({required this.fallback, this.vision = const VisionOcr()});
  final OcrEngine fallback;
  final VisionOcr vision;

  @override
  String get name => 'vision';

  static List<String> hints(OcrLanguage language) => switch (language) {
    OcrLanguage.auto => const ['de-DE', 'en-US'],
    OcrLanguage.german => const ['de-DE'],
    OcrLanguage.english => const ['en-US'],
  };

  @override
  Future<PageOcr> recognize(
    String imagePath, {
    OcrLanguage language = OcrLanguage.auto,
  }) async {
    final List<OcrWord> found;
    try {
      found = await vision.recognize(imagePath, languages: hints(language));
    } on VisionOcrException catch (e) {
      if (e.error == VisionOcrError.notAnImage) {
        throw const OcrException(OcrFailure.notAnImage);
      }
      return fallback.recognize(imagePath, language: language);
    }
    final words = [
      for (final w in found)
        (text: w.text, box: w.box, confidence: w.confidence),
    ];
    final raster = decodeRaster(await File(imagePath).readAsBytes());
    return PageOcr(name, words, judge(words, sharpness(raster)));
  }

  /// Vision reads files: the raster goes to [scratch] as a PNG first.
  @override
  Future<PageOcr> recognizeRaster(
    Raster raster, {
    OcrLanguage language = OcrLanguage.auto,
    required Directory scratch,
  }) async {
    final rgb = img.Image.fromBytes(
      width: raster.width,
      height: raster.height,
      bytes: raster.bgr.buffer,
      numChannels: 3,
      order: img.ChannelOrder.bgr,
    );
    final path = '${scratch.path}/vision_page.png';
    await File(path).writeAsBytes(img.encodePng(rgb));
    try {
      return await recognize(path, language: language);
    } finally {
      await File(path).delete();
    }
  }

  @override
  Future<void> close() => fallback.close();
}

/// The OCR failures the error catalogue knows (UI spec §26.3: damaged file).
enum OcrFailure { notAnImage }

class OcrException implements Exception {
  const OcrException(this.failure);
  final OcrFailure failure;

  @override
  String toString() => 'OcrException(${failure.name})';
}

/// The character error rate of [hypothesis] against [reference]: edit
/// distance over the reference length (DK-0400's quality measure).
double characterErrorRate(String reference, String hypothesis) {
  final a = reference.runes.toList(), b = hypothesis.runes.toList();
  var previous = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      current[j] = math.min(
        math.min(current[j - 1] + 1, previous[j] + 1),
        previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
      );
    }
    previous = current;
  }
  return a.isEmpty ? 0 : previous[b.length] / a.length;
}
