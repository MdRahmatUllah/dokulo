/// Apple Vision text recognition (DK-0397): the default OCR on iOS, with
/// PP-OCRv5 as the fallback and the engine on Android (the OCR facade,
/// DK-0400, picks one).
///
/// The recognition itself runs in Vision on a background queue, so the
/// calling isolate only waits. A worker isolate may call [VisionOcr.recognize]
/// once it has run `BackgroundIsolateBinaryMessenger.ensureInitialized` with
/// the root isolate's token.
library;

import 'package:flutter/services.dart';

/// One recognised word.
class OcrWord {
  const OcrWord(this.text, this.box, this.confidence);

  final String text;

  /// The word's box on the image, normalised to 0..1 with the origin at the
  /// top left: (left, top, width, height). Vision's bottom-left origin is
  /// converted on the platform side.
  final ({double left, double top, double width, double height}) box;

  /// Vision's confidence for the line the word is in, 0..1.
  final double confidence;
}

/// Why recognition failed; the OCR facade maps these to the error catalogue.
enum VisionOcrError {
  /// No Vision here (Android, or iOS before 16): use PP-OCRv5.
  unavailable,

  /// The file isn't an image Vision can read.
  notAnImage,

  /// Vision ran and failed.
  failed,
}

class VisionOcrException implements Exception {
  const VisionOcrException(this.error, [this.detail = '']);

  final VisionOcrError error;
  final String detail;

  @override
  String toString() => 'VisionOcrException(${error.name}) $detail';
}

class VisionOcr {
  const VisionOcr();

  static const channel = MethodChannel('dokulo/vision_ocr');

  /// The words on the image at [imagePath], in reading order. [languages]
  /// are hints in Vision's codes (`de-DE`, `en-US`), most likely first.
  Future<List<OcrWord>> recognize(
    String imagePath, {
    List<String> languages = const ['de-DE', 'en-US'],
  }) async {
    final List<Object?>? words;
    try {
      words = await channel.invokeListMethod<Object?>('recognize', {
        'path': imagePath,
        'languages': languages,
      });
    } on MissingPluginException {
      throw const VisionOcrException(VisionOcrError.unavailable);
    } on PlatformException catch (e) {
      throw VisionOcrException(switch (e.code) {
        'unavailable' => VisionOcrError.unavailable,
        'not_an_image' => VisionOcrError.notAnImage,
        _ => VisionOcrError.failed,
      }, e.message ?? '');
    }
    return [
      for (final w in words ?? const [])
        if (w case {
          'text': final String text,
          'box': [
            final num left,
            final num top,
            final num width,
            final num height,
          ],
          'confidence': final num confidence,
        })
          OcrWord(text, (
            left: left.toDouble(),
            top: top.toDouble(),
            width: width.toDouble(),
            height: height.toDouble(),
          ), confidence.toDouble()),
    ];
  }
}
