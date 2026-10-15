import 'dart:io';
import 'dart:typed_data';

import 'package:ai_core/ai_core.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:qpdf_ffi/qpdf_ffi.dart';

import 'id_card_page.dart' show a4Height, a4Width;
import 'pdf_engine.dart';
import 'qpdf_service.dart';

/// Image to PDF's page size (UI spec §21.7): the image's own proportions, or
/// A4 or Letter turned to the image's orientation.
enum ImagePageSize { fit, a4, letter }

/// Letter in points.
const letterWidth = 612.0, letterHeight = 792.0;

/// The "Small" margin, in points (about 8.5 mm).
const smallMargin = 24.0;

/// Where an image of [width] × [height] pixels goes: the page size and the
/// image's box on it (points, origin bottom-left). A "Fit image" page has
/// the image's proportions with its long side as long as A4's.
({double pageWidth, double pageHeight, Box image}) imagePageLayout(
  int width,
  int height,
  ImagePageSize size, {
  bool margins = false,
}) {
  final m = margins ? smallMargin : 0.0;
  final landscape = width > height;
  final (double pageWidth, double pageHeight) = switch (size) {
    ImagePageSize.fit => (
      (landscape ? a4Height : a4Height * width / height) + 2 * m,
      (landscape ? a4Height * height / width : a4Height) + 2 * m,
    ),
    ImagePageSize.a4 => landscape ? (a4Height, a4Width) : (a4Width, a4Height),
    ImagePageSize.letter =>
      landscape ? (letterHeight, letterWidth) : (letterWidth, letterHeight),
  };
  // Scaled to fit inside the margins, up or down, and centred.
  final scale = [
    (pageWidth - 2 * m) / width,
    (pageHeight - 2 * m) / height,
  ].reduce((a, b) => a < b ? a : b);
  final w = width * scale, h = height * scale;
  final left = (pageWidth - w) / 2, bottom = (pageHeight - h) / 2;
  return (
    pageWidth: pageWidth,
    pageHeight: pageHeight,
    image: (left: left, top: bottom + h, right: left + w, bottom: bottom),
  );
}

/// Writes images as PDF pages (DK-0432: Image to PDF), one image per page.
/// A JPEG goes in as it is, never re-encoded, turned by its EXIF
/// orientation; PNG, WebP, GIF, BMP and TIFF are decoded and embedded
/// lossless. The `pdf` writer holds a document in memory, so pages go into
/// batch files of about [batchBytes] in [workDir], which qpdf joins at the
/// end: 500 photos never sit in memory at once. Run it off the UI isolate.
class ImagesPdfWriter {
  ImagesPdfWriter(
    this.output, {
    required this.workDir,
    this.size = ImagePageSize.fit,
    this.margins = false,
    this.batchBytes = 96 << 20,
  });

  final String output;
  final Directory workDir;
  final ImagePageSize size;
  final bool margins;
  final int batchBytes;

  final _batches = <String>[];
  pw.PdfDocument? _doc;
  var _held = 0;
  var _pages = 0;

  /// Adds [encoded] as the next page. Throws [DocError] `damaged` (with the
  /// page) when it is not an image this writer can read.
  Future<void> add(Uint8List encoded) async {
    final doc = _doc ??= pw.PdfDocument();
    final pw.PdfImage image;
    try {
      image = pw.PdfImage.file(doc, bytes: encoded);
    } catch (e) {
      throw DocError(
        DocErrorKind.damaged,
        page: _pages,
        detail: 'not a readable image: $e',
      );
    }
    final layout = imagePageLayout(
      image.width,
      image.height,
      size,
      margins: margins,
    );
    final page = pw.PdfPage(
      doc,
      pageFormat: pw.PdfPageFormat(layout.pageWidth, layout.pageHeight),
    );
    final box = layout.image;
    page.getGraphics().drawImage(
      image,
      box.left,
      box.bottom,
      box.right - box.left,
      box.top - box.bottom,
    );
    _pages++;
    // A JPEG (FF D8) is held as it is; a decoded image as its RGBA pixels.
    final jpeg = encoded.length > 2 && encoded[0] == 0xFF && encoded[1] == 0xD8;
    _held += jpeg ? encoded.length : image.width * image.height * 4;
    if (_held >= batchBytes) await _flush();
  }

  Future<void> _flush() async {
    final doc = _doc;
    if (doc == null) return;
    final path = '${workDir.path}/img2pdf_${_batches.length}.pdf';
    File(path).writeAsBytesSync(await doc.save());
    _batches.add(path);
    _doc = null;
    _held = 0;
  }

  /// Writes [output]: the one batch moved there, or the batches joined by
  /// qpdf on [pool]'s qpdf worker. Returns the page count.
  Future<int> close(IsolatePool pool) async {
    await _flush();
    if (_batches.isEmpty) throw ArgumentError('no images');
    if (_batches.length == 1) {
      final batch = File(_batches.single);
      try {
        batch.renameSync(output);
      } on FileSystemException {
        // Another volume: copy, then drop the batch.
        batch
          ..copySync(output)
          ..deleteSync();
      }
    } else {
      await pool.run(Lane.qpdf, _join, (List.of(_batches), output)).result;
      for (final b in _batches) {
        File(b).deleteSync();
      }
    }
    _batches.clear();
    return _pages;
  }
}

void _join((List<String>, String) job, JobContext context) => QpdfService.run(
  () => Qpdf.run({
    'inputFile': job.$1.first,
    'outputFile': job.$2,
    'pages': [
      for (final f in job.$1) {'file': f},
    ],
  }),
);
