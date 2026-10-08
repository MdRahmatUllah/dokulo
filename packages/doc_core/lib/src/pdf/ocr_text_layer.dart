import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pw;

import 'package:qpdf_ffi/qpdf_ffi.dart';

import 'pdf_engine.dart';
import 'qpdf_service.dart';

/// A recognised word for the text layer: the text and its box on the page as
/// displayed (after the page's rotation, within its crop box), normalised to
/// 0..1 with the origin at the top left, the way the OCR facade (DK-0400)
/// reports it. `doc_tools` maps the OCR result to these; doc_core can't
/// depend on doc_vision (same layer).
class LayerWord {
  const LayerWord(this.text, this.box);
  final String text;
  final ({double left, double top, double width, double height}) box;
}

/// The invisible OCR text layer (DK-0394): what makes a scan searchable and
/// selectable, and what redaction (DK-0393) and PDF/A (DK-0395) build on.
///
/// Each page gets an overlay page of its displayed size with the words as
/// invisible text (rendering mode 3), each word in Helvetica sized to its
/// box's height and scaled horizontally (Tz) to its box's width. qpdf's
/// overlay (`Qpdf.overlay`) then places every overlay page upright into its
/// page's crop box, undoing the page's /Rotate, so the words land where the
/// OCR saw them. Invisible text needs no embedded font, in PDF/A-2 too.
abstract final class OcrTextLayer {
  /// The overlay PDF: one page per entry of [pages] (sizes as displayed),
  /// carrying the words of [words] (by 0-based page); pages without words are
  /// empty. A page with an entry in [images] (RGBA, as [PdfEngine.render]
  /// gives it after a BGRA→RGBA swap) gets that picture as its visible
  /// content under the words: a rasterised page that stays searchable
  /// (PDF/A, DK-0395). [jpegs] does the same with a JPEG (Compress PDF's
  /// raster fallback, DK-0392).
  static Future<Uint8List> overlay(
    List<PageInfo> pages,
    Map<int, List<LayerWord>> words, {
    Map<int, ({Uint8List rgba, int width, int height})> images = const {},
    Map<int, Uint8List> jpegs = const {},
  }) {
    final doc = pw.PdfDocument();
    final font = pw.PdfFont.helvetica(doc);
    final lineHeight = font.ascent - font.descent; // descent is negative
    for (final (index, info) in pages.indexed) {
      final page = pw.PdfPage(
        doc,
        pageFormat: pw.PdfPageFormat(info.width, info.height),
      );
      final g = page.getGraphics();
      if (jpegs[index] case final jpeg?) {
        g.drawImage(
          pw.PdfImage.jpeg(doc, image: jpeg),
          0,
          0,
          info.width,
          info.height,
        );
      } else if (images[index] case final image?) {
        final picture = pw.PdfImage(
          doc,
          image: image.rgba,
          width: image.width,
          height: image.height,
          alpha: false,
        );
        g.drawImage(picture, 0, 0, info.width, info.height);
      }
      for (final word in words[index] ?? const <LayerWord>[]) {
        final text = encodable(word.text);
        if (text.trim().isEmpty) continue;
        final width = word.box.width * info.width;
        final height = word.box.height * info.height;
        if (width <= 0 || height <= 0) continue;
        final size = height / lineHeight;
        final natural = font.stringMetrics(text).advanceWidth * size;
        g.drawString(
          font,
          size,
          text,
          word.box.left * info.width,
          // PDF's origin is the bottom left; the baseline sits a descent above the box's bottom.
          info.height -
              (word.box.top + word.box.height) * info.height -
              font.descent * size,
          scale: natural > 0 ? width / natural : null,
          mode: pw.PdfTextRenderingMode.invisible,
        );
      }
    }
    return doc.save();
  }

  /// Helvetica in the overlay speaks Latin-1 (WinAnsi): German and English
  /// in full. Anything else becomes "?", so the text stays selectable; the
  /// multilingual OCR's scripts need an embedded font later.
  static String encodable(String text) =>
      String.fromCharCodes(text.runes.map((c) => c <= 0xFF ? c : 0x3F));

  /// Writes the overlay for [input]'s pages to [overlayPath] and returns it;
  /// [apply] then lays it over the pages. (Two steps: this one reads the page
  /// sizes through PDFium, [apply] runs qpdf in a `Lane.qpdf` job.)
  static Future<String> writeOverlay(
    String input,
    Map<int, List<LayerWord>> words,
    String overlayPath, {
    String? password,
  }) async {
    final info = await PdfEngine.inspect(input, password: password);
    await File(overlayPath).writeAsBytes(await overlay(info.pages, words));
    return overlayPath;
  }

  /// Lays [overlayPath] over [input]'s pages into [output] (page n on page
  /// n): call it inside a `Lane.qpdf` job. qpdf places each overlay page
  /// upright in its page's crop box, undoing /Rotate. A locked [input] needs
  /// its [password] (the output keeps the encryption); without it, it fails
  /// as [DocErrorKind.locked].
  static List<String> apply(
    String input,
    String overlayPath,
    String output, {
    String? password,
  }) => QpdfService.run(
    () => Qpdf.overlay(input, overlayPath, output, password: password),
  );
}
