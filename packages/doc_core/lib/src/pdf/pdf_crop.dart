import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pdfrx_engine/pdfrx_engine.dart' show PdfrxEntryFunctions;

import 'pdf_engine.dart';
import 'pdfium_raw.dart';

/// How much to cut from each edge of a page, as shares (0–1) of the page as
/// it is displayed (after its rotation): what DkCropOverlay shows.
typedef CropInsets = ({double left, double top, double right, double bottom});

/// Crop pages (UI spec §21.17; DK-0492): sets each page's crop box, so the
/// content outside stays in the file (non-destructive) and a later crop can
/// widen it again.
abstract final class PdfCrop {
  /// Writes [outPath] with the crop of [insets] on each page in it
  /// (0-based); the others stay as they are.
  static Future<void> crop(
    String path,
    String outPath,
    Map<int, CropInsets> insets, {
    String? password,
  }) async {
    final count = (await PdfEngine.inspect(path, password: password)).pageCount;
    for (final MapEntry(key: page, value: i) in insets.entries) {
      if (page < 0 || page >= count) {
        throw ArgumentError('page $page of $count');
      }
      if ([i.left, i.top, i.right, i.bottom].any((v) => v < 0) ||
          i.left + i.right >= 1 ||
          i.top + i.bottom >= 1) {
        throw ArgumentError('insets $i leave nothing');
      }
    }
    final bytes = await PdfrxEntryFunctions.instance.compute(_cropOnWorker, (
      path,
      password,
      insets,
    ));
    await File(outPath).writeAsBytes(bytes, flush: true);
  }

  /// Auto margins: the page's content bounds on a 50 dpi render (anything
  /// darker than near-white), as insets with a small margin kept; none for
  /// an empty page.
  static Future<CropInsets> contentInsets(
    String path,
    int page, {
    String? password,
  }) async {
    final r = await PdfEngine.render(path, page, dpi: 50, password: password);
    var l = r.width, t = r.height, rt = -1, b = -1;
    for (var y = 0; y < r.height; y++) {
      for (var x = 0; x < r.width; x++) {
        final i = (y * r.width + x) * 4;
        if (r.bgra[i] < 235 || r.bgra[i + 1] < 235 || r.bgra[i + 2] < 235) {
          l = min(l, x);
          rt = max(rt, x);
          t = min(t, y);
          b = max(b, y);
        }
      }
    }
    if (rt < 0) return (left: 0.0, top: 0.0, right: 0.0, bottom: 0.0);
    // About 6 pt of air around the content.
    const keep = 4;
    double share(int px, int of) => (px - keep).clamp(0, of) / of;
    return (
      left: share(l, r.width),
      top: share(t, r.height),
      right: share(r.width - 1 - rt, r.width),
      bottom: share(r.height - 1 - b, r.height),
    );
  }
}

/// On pdfrx's worker: the crop boxes set, the document saved.
Uint8List _cropOnWorker((String, String?, Map<int, CropInsets>) m) =>
    withRawDocument(m.$1, m.$2, (pdfium, doc, arena) {
      final l = arena<Float>(), b = arena<Float>();
      final r = arena<Float>(), t = arena<Float>();
      for (final MapEntry(key: index, value: insets) in m.$3.entries) {
        final page = pdfium.FPDF_LoadPage(doc, index);
        try {
          // From the current crop box, or the media box without one.
          if (pdfium.FPDFPage_GetCropBox(page, l, b, r, t) == 0 &&
              pdfium.FPDFPage_GetMediaBox(page, l, b, r, t) == 0) {
            throw StateError('page $index has no media box');
          }
          // The insets are of the page as displayed; the box is in the
          // page's own space: turn them back by its rotation.
          final shown = [insets.left, insets.top, insets.right, insets.bottom];
          final turns = pdfium.FPDFPage_GetRotation(page) % 4;
          final u = [for (var k = 0; k < 4; k++) shown[(k + turns) % 4]];
          final w = r.value - l.value, h = t.value - b.value;
          pdfium.FPDFPage_SetCropBox(
            page,
            l.value + u[0] * w,
            b.value + u[3] * h,
            r.value - u[2] * w,
            t.value - u[1] * h,
          );
        } finally {
          pdfium.FPDF_ClosePage(page);
        }
      }
      return saveRawDocument(pdfium, doc);
    });
