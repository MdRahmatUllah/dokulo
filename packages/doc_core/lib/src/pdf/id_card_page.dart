import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pw;

import 'pdf_engine.dart';

/// ID-1, the size of an ID or bank card (ISO/IEC 7810): 85.6 × 54 mm.
const idCardWidthMm = 85.6, idCardHeightMm = 54.0;

/// A4 in points.
const a4Width = 595.2756, a4Height = 841.8898;

const _pointsPerMm = 72 / 25.4;

/// The gap between the front and the back on the page.
const idCardGapMm = 15.0;

/// Where the front and the back go on an A4 page (DK-0340): each at true
/// size, the front above the back, the pair centred. Page space: points,
/// origin bottom-left.
({Box front, Box back}) idCardLayout() {
  const w = idCardWidthMm * _pointsPerMm, h = idCardHeightMm * _pointsPerMm;
  const gap = idCardGapMm * _pointsPerMm;
  const left = (a4Width - w) / 2;
  const top = (a4Height + 2 * h + gap) / 2;
  return (
    front: (left: left, top: top, right: left + w, bottom: top - h),
    back: (
      left: left,
      top: top - h - gap,
      right: left + w,
      bottom: top - 2 * h - gap,
    ),
  );
}

/// One A4 page with [front] and [back] (JPEGs already cropped to the card,
/// in ID-1's proportions) at true size, so the printout measures 85.6 × 54
/// mm (DK-0340: ID card mode).
Future<Uint8List> idCardPdf(Uint8List front, Uint8List back) {
  final doc = pw.PdfDocument();
  final page = pw.PdfPage(
    doc,
    pageFormat: const pw.PdfPageFormat(a4Width, a4Height),
  );
  final g = page.getGraphics();
  final layout = idCardLayout();
  for (final (jpeg, box) in [(front, layout.front), (back, layout.back)]) {
    g.drawImage(
      pw.PdfImage.jpeg(doc, image: jpeg),
      box.left,
      box.bottom,
      box.right - box.left,
      box.top - box.bottom,
    );
  }
  return doc.save();
}
