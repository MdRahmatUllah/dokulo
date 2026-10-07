import 'dart:io';
import 'dart:typed_data';

import '../ocr_text_layer.dart';
import '../pdf_engine.dart';
import '../pdfa_writer.dart';

/// Encodes RGBA pixels as a JPEG at [quality] (40–85). The image pipeline
/// passes OpenCV's encoder (libjpeg-turbo, on its own isolate); tests pass
/// a pure-Dart one.
typedef JpegEncoder = Future<Uint8List> Function(
  Uint8List rgba,
  int width,
  int height,
  int quality,
);

/// Compress PDF's raster fallback for scans (DK-0392): [pages] of [input]
/// are rendered at [dpi] and stored as one JPEG each at [quality], with the
/// page's own text (an OCR layer, if it has one) kept as invisible text, so a
/// searchable scan stays searchable. The other pages are copied as they are.
/// Writes [output]; [work] holds the pictures while it runs.
abstract final class RasterFallback {
  static Future<void> rasterise(
    String input,
    String output,
    List<int> pages, {
    required int dpi,
    required int quality,
    required JpegEncoder encodeJpeg,
    required Directory work,
    String? password,
  }) async {
    final info = await PdfEngine.inspect(input, password: password);
    final jpegs = <int, Uint8List>{};
    final words = <int, List<LayerWord>>{};
    for (final (i, p) in pages.indexed) {
      final shot = await PdfEngine.render(
        input,
        p,
        dpi: dpi.toDouble(),
        password: password,
      );
      jpegs[i] = await encodeJpeg(shot.rgba, shot.width, shot.height, quality);
      words[i] = PdfaWriter.wordsOf(
        await PdfEngine.pageText(input, p, password: password),
        info.pages[p],
      );
    }
    final pictures = '${work.path}/compress-pictures-$dpi-$quality.pdf';
    await File(pictures).writeAsBytes(
      await OcrTextLayer.overlay(
        [for (final p in pages) info.pages[p]],
        words,
        jpegs: jpegs,
      ),
    );
    await PdfEngine.assemble(
      [
        for (var p = 0; p < info.pageCount; p++)
          pages.contains(p)
              ? PageSource(pictures, pages.indexOf(p))
              : PageSource(input, p),
      ],
      output,
      passwords: {input: ?password},
    );
  }
}
