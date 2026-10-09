import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:doc_vision/doc_vision.dart';

export 'package:doc_vision/doc_vision.dart' show documentThreshold;

/// Scores library thumbnails for the photo finder (DK-0362): OpenCV (the
/// decode and the page quad) on a worker isolate, then the platform's OCR
/// (Vision on iOS, PP-OCRv5 elsewhere) for the text, into [documentScore].
/// No network: the models are bundled.
class DocumentPhotoScorer {
  DocumentPhotoScorer({Future<OcrEngine> Function()? engine})
    : _make = engine ?? OcrEngine.forPlatform;

  final Future<OcrEngine> Function() _make;
  Future<OcrEngine>? _engine;

  Future<double> call(Uint8List image) async {
    final decoded = await Isolate.run(() => decodeForScoring(image));
    if (decoded == null) return 0;
    final engine = await (_engine ??= _make());
    final ocr = await engine.recognizeRaster(
      decoded.raster,
      scratch: Directory.systemTemp,
    );
    return documentScore(
      width: decoded.raster.width,
      height: decoded.raster.height,
      words: ocr.words,
      quad: decoded.quad,
    );
  }

  /// Frees the OCR engine.
  Future<void> close() async => (await _engine)?.close();
}
