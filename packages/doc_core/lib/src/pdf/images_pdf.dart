import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pw;

import 'id_card_page.dart' show a4Height, a4Width;

/// US Letter in points.
const letterWidth = 612.0, letterHeight = 792.0;

/// The page an image goes on.
enum ImagesPdfPage {
  /// The image's own proportions, A4's width (a scan, Image to PDF's "Fit
  /// image").
  fit,

  /// A4 or Letter, the image fitted inside, centred, the long sides matching
  /// the page's way up.
  a4,
  letter,
}

/// One page per JPEG (DK-0359 scans; Image to PDF): the JPEGs go in as they
/// are (DCT, no re-encoding), so the file is the size of its images.
Future<Uint8List> imagesPdf(
  List<({Uint8List jpeg, int width, int height})> images, {
  ImagesPdfPage page = ImagesPdfPage.fit,
}) {
  final doc = pw.PdfDocument();
  for (final im in images) {
    final landscape = im.width > im.height;
    final (pageW, pageH) = switch (page) {
      ImagesPdfPage.fit => (a4Width, a4Width * im.height / im.width),
      ImagesPdfPage.a4 => landscape ? (a4Height, a4Width) : (a4Width, a4Height),
      ImagesPdfPage.letter =>
        landscape ? (letterHeight, letterWidth) : (letterWidth, letterHeight),
    };
    final scale = [
      pageW / im.width,
      pageH / im.height,
    ].reduce((a, b) => a < b ? a : b);
    final w = im.width * scale, h = im.height * scale;
    final p = pw.PdfPage(doc, pageFormat: pw.PdfPageFormat(pageW, pageH));
    p.getGraphics().drawImage(
      pw.PdfImage.jpeg(doc, image: im.jpeg),
      (pageW - w) / 2,
      (pageH - h) / 2,
      w,
      h,
    );
  }
  return doc.save();
}
