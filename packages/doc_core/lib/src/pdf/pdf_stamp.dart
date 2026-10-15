import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Where a stamp sits on a page: x and y from -1 (left, top) to 1 (right,
/// bottom), as DkPositionPicker's cells.
typedef StampAlign = ({double x, double y});

/// The stamp pages that Add page numbers and Add watermark lay over (or
/// under) a document with qpdf (UI spec §21.15, §21.16): one page per
/// document page, the same size as it is displayed. Pure Dart: run it off
/// the UI isolate. Helvetica speaks Latin-1, enough for EN and DE.
abstract final class PdfStamp {
  /// One number per page in [sizes] (points, as displayed): [label] gives
  /// the page's text ("3", "3 of 12"), or null for none (Skip first page).
  static Future<void> pageNumbers(
    List<({double width, double height})> sizes,
    String output, {
    required String? Function(int page) label,
    StampAlign align = (x: 0, y: 1),
    double fontSize = 10,
    double margin = 24,
  }) => _write(output, [
    for (final (i, size) in sizes.indexed)
      _page(size, switch (label(i)) {
        final text? => pw.Padding(
          padding: pw.EdgeInsets.all(margin),
          child: pw.Align(
            alignment: pw.Alignment(align.x, -align.y),
            child: pw.Text(
              text,
              style: pw.TextStyle(fontSize: fontSize, color: PdfColors.black),
            ),
          ),
        ),
        null => pw.SizedBox(),
      }),
  ]);

  /// [text] or [image] across each page in [pages] (0-based; all when
  /// null), at [opacity] (0–1), turned [degrees] counter-clockwise, once in
  /// the centre or [tiled]. [size] is the text's font size, or the image's
  /// width as a share of the page's.
  static Future<void> watermark(
    List<({double width, double height})> sizes,
    String output, {
    String? text,
    Uint8List? image,
    double opacity = 0.3,
    double degrees = 45,
    double size = 48,
    bool tiled = false,
    Set<int>? pages,
  }) {
    if ((text == null) == (image == null)) {
      throw ArgumentError('a text or an image');
    }
    final picture = image == null ? null : pw.MemoryImage(image);
    pw.Widget mark(double pageWidth) => pw.Opacity(
      opacity: opacity,
      child: pw.Transform.rotate(
        angle: degrees * pi / 180,
        child: picture == null
            ? pw.Text(
                text!,
                style: pw.TextStyle(
                  fontSize: size,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              )
            : pw.Image(picture, width: pageWidth * size.clamp(0.05, 1)),
      ),
    );
    return _write(output, [
      for (final (i, s) in sizes.indexed)
        _page(
          s,
          pages != null && !pages.contains(i)
              ? pw.SizedBox()
              : !tiled
              ? pw.Center(child: mark(s.width))
              : pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var r = 0; r < 4; r++)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                        children: [
                          for (var c = 0; c < 2; c++) mark(s.width / 3),
                        ],
                      ),
                  ],
                ),
        ),
    ]);
  }

  static pw.Page _page(({double width, double height}) size, pw.Widget child) =>
      pw.Page(
        pageFormat: PdfPageFormat(size.width, size.height),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.SizedBox.expand(child: child),
      );

  static Future<void> _write(String output, List<pw.Page> pages) async {
    final doc = pw.Document(compress: true);
    pages.forEach(doc.addPage);
    await File(output).writeAsBytes(await doc.save());
  }
}
