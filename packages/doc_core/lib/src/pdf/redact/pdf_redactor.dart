import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:pdfium_dart/pdfium_dart.dart' as fpdf;
import 'package:pdfrx_engine/pdfrx_engine.dart' show PdfrxEntryFunctions;
import 'package:qpdf_ffi/qpdf_ffi.dart';

import '../ocr_text_layer.dart';
import '../pdf_engine.dart';
import '../qpdf_service.dart';
import 'detectors.dart';

/// An area to black out: in page space (PDF points, origin bottom-left, the
/// page unrotated), as PDFium's character boxes are. A finding gives one per
/// line it spans; the review sheet lets the user move, add and drop them.
class RedactionBox {
  const RedactionBox(this.page, this.box, {this.text = '', this.kind});
  final int page;
  final Box box;

  /// The text under the box, for the leak check; empty for a hand-drawn box.
  final String text;
  final SensitiveKind? kind;

  @override
  String toString() => 'p$page ${kind?.name ?? 'manual'} "$text" $box';
}

/// What [PdfRedactor.prepare] wrote, for [PdfRedactor.finish]. Plain paths,
/// so it can be sent to the qpdf isolate.
class RedactionPlan {
  const RedactionPlan(this.pages, this.textLayer);

  /// The new document: redacted pages as images, the others copied, no
  /// annotations, no document-level extras.
  final String pages;

  /// The invisible text of the redacted pages, minus the redacted words.
  final String textLayer;
}

/// True redaction (DK-0393; Technology plan, `pdf_redact`). Pages with a box
/// are rasterised, the boxes burnt into the pixels, and the page rebuilt as
/// that image plus invisible text of the words that remain, so nothing under
/// a box survives in any form. The output is a new document (no outline,
/// attachments, JavaScript, XMP or document info), without annotations on
/// any page, written out in full by qpdf. [textLeaks] and [rawLeaks] prove
/// it: neither PDFium's text nor the uncompressed file holds a redacted
/// string.
///
/// The PDFium steps ([find], [prepare], [textLeaks]) run through pdfrx from
/// the main isolate; the qpdf steps ([finish], [rawLeaks]) inside a
/// `Lane.qpdf` job, as a ToolJob composes them.
abstract final class PdfRedactor {
  /// Raster resolution of redacted pages: sharp enough to read and print.
  static const dpi = 200.0;

  /// The detectors' findings on every page, as boxes.
  static Future<List<RedactionBox>> find(
    String path, {
    String? password,
  }) async {
    final info = await PdfEngine.inspect(path, password: password);
    final boxes = <RedactionBox>[];
    for (var page = 0; page < info.pageCount; page++) {
      final text = await PdfEngine.pageText(path, page, password: password);
      for (final f in findSensitive(text.text)) {
        for (final box in lineBoxes(text.charBoxes, f.start, f.end)) {
          boxes.add(RedactionBox(page, box, text: f.text, kind: f.kind));
        }
      }
    }
    return boxes;
  }

  /// The boxes of characters [start]..[end], one per line (a new line where
  /// a character lies wholly below the box so far: a full stop or a hyphen
  /// sits low but on the same line).
  static List<Box> lineBoxes(List<Box> chars, int start, int end) {
    final out = <Box>[];
    Box? current;
    for (var i = start; i < end && i < chars.length; i++) {
      final c = chars[i];
      if (c.right <= c.left || c.top <= c.bottom) continue; // a generated space
      if (current != null && c.top < current.bottom) {
        out.add(current);
        current = null;
      }
      current = current == null
          ? c
          : (
              left: math.min(current.left, c.left),
              top: math.max(current.top, c.top),
              right: math.max(current.right, c.right),
              bottom: math.min(current.bottom, c.bottom),
            );
    }
    if (current != null) out.add(current);
    return out;
  }

  /// Rasterises the pages with [boxes], burns the boxes in, puts the new
  /// document together without annotations and writes the remaining words'
  /// text layer, all under [work]. Then run [finish] in a `Lane.qpdf` job.
  static Future<RedactionPlan> prepare(
    String input,
    List<RedactionBox> boxes,
    Directory work, {
    String? password,
  }) async {
    await work.create(recursive: true);
    final info = await PdfEngine.inspect(input, password: password);
    final byPage = <int, List<RedactionBox>>{};
    for (final b in boxes) {
      (byPage[b.page] ??= []).add(b);
    }
    final redacted = byPage.keys.toList()..sort();

    // 1. The redacted pages as images, boxes burnt in.
    final images = pw.PdfDocument();
    for (final page in redacted) {
      final p = info.pages[page];
      final shown = [for (final b in byPage[page]!) displayed(b.box, p)];
      final raster = await PdfEngine.render(
        input,
        page,
        dpi: dpi,
        password: password,
      );
      final rgb = _burn(raster, shown, margin: dpi / 72);
      final imagePage = pw.PdfPage(
        images,
        pageFormat: pw.PdfPageFormat(p.width, p.height),
      );
      imagePage.getGraphics().drawImage(
        pw.PdfImage(
          images,
          image: rgb,
          width: raster.width,
          height: raster.height,
          alpha: false,
        ),
        0,
        0,
        p.width,
        p.height,
      );
    }
    final imagesPath = '${work.path}/redacted-pages.pdf';
    await File(imagesPath).writeAsBytes(await images.save());

    // 2. The new document: image pages where redacted, the rest copied.
    final assembled = '${work.path}/assembled.pdf';
    await PdfEngine.assemble(
      [
        for (var page = 0; page < info.pageCount; page++)
          redacted.contains(page)
              ? PageSource(imagesPath, redacted.indexOf(page))
              : PageSource(input, page),
      ],
      assembled,
      passwords: {input: ?password},
    );

    // 3. No annotations on any page (notes, links and fields can carry text).
    final stripped = '${work.path}/stripped.pdf';
    await File(stripped).writeAsBytes(
      await PdfrxEntryFunctions.instance.compute(
        _withoutAnnotationsOnWorker,
        assembled,
      ),
    );

    // 4. The redacted pages' remaining words as invisible text.
    final layer = <int, List<LayerWord>>{};
    for (final page in redacted) {
      final p = info.pages[page];
      final text = await PdfEngine.pageText(input, page, password: password);
      final hidden = [for (final b in byPage[page]!) b.box];
      layer[page] = [
        for (final (word, box) in _words(text))
          if (!hidden.any((h) => _overlap(h, box)))
            LayerWord(word, displayed(box, p)),
      ];
    }
    final textLayer = await OcrTextLayer.writeOverlay(
      stripped,
      layer,
      '${work.path}/text-layer.pdf',
    );
    return RedactionPlan(stripped, textLayer);
  }

  /// Inside a `Lane.qpdf` job: lays the text layer over the pages and writes
  /// [output] in full: no document info, no XMP, compressed object streams.
  static void finish(RedactionPlan plan, String output) {
    final layered = '$output.layered.pdf';
    OcrTextLayer.apply(plan.pages, plan.textLayer, layered);
    QpdfService.run(
      () => Qpdf.run({
        'inputFile': layered,
        'outputFile': output,
        'removeInfo': '',
        'removeMetadata': '',
        'objectStreams': 'generate',
        'compressStreams': 'y',
      }),
    );
    File(layered).deleteSync();
  }

  /// The [strings] PDFium still finds in [path]'s text (spaces ignored).
  static Future<List<String>> textLeaks(
    String path,
    Iterable<String> strings,
  ) async {
    final info = await PdfEngine.inspect(path);
    final all = StringBuffer();
    for (var page = 0; page < info.pageCount; page++) {
      all.write((await PdfEngine.pageText(path, page)).text);
    }
    final text = _squash(all.toString());
    return [
      for (final s in strings)
        if (s.trim().isNotEmpty && text.contains(_squash(s))) s,
    ];
  }

  /// Inside a `Lane.qpdf` job: the [strings] that occur in [path] written out
  /// uncompressed (QDF) to [scratch], as Latin-1 or UTF-16 bytes, with or
  /// without spaces: metadata, attachments, form values, stray streams.
  static List<String> rawLeaks(
    String path,
    Iterable<String> strings,
    String scratch,
  ) {
    QpdfService.run(
      () => Qpdf.run({
        'inputFile': path,
        'outputFile': scratch,
        'qdf': '',
        'objectStreams': 'disable',
        'streamData': 'uncompress',
      }),
    );
    final bytes = File(scratch).readAsBytesSync();
    File(scratch).deleteSync();
    bool contains(List<int> needle) {
      outer:
      for (var i = 0; i + needle.length <= bytes.length; i++) {
        for (var j = 0; j < needle.length; j++) {
          if (bytes[i + j] != needle[j]) continue outer;
        }
        return true;
      }
      return false;
    }

    List<int> latin(String s) => [
      for (final c in s.runes) c <= 0xff ? c : 0x3f,
    ];
    List<int> utf16(String s) => [
      for (final c in s.codeUnits) ...[c >> 8, c & 0xff],
    ];
    return [
      for (final s in strings)
        if (s.trim().isNotEmpty &&
            {
              s,
              _squash(s),
            }.any((v) => contains(latin(v)) || contains(utf16(v))))
          s,
    ];
  }

  /// Annotations on all pages of [path], for the leak check.
  static Future<int> annotationCount(String path) =>
      PdfrxEntryFunctions.instance.compute(_annotationCountOnWorker, path);

  /// [box] (page space) on the page as displayed, normalised to 0..1 from
  /// the top left: what the rendered image and the text layer use.
  /// ponytail: assumes the crop box is the media box at (0, 0), true for
  /// what Dokulo writes and for most PDFs; FPDF_PageToDevice if not.
  static ({double left, double top, double width, double height}) displayed(
    Box box,
    PageInfo page,
  ) {
    final turns = page.quarterTurns % 4;
    final w = turns.isOdd ? page.height : page.width,
        h = turns.isOdd ? page.width : page.height;
    (double, double) turn(double u, double v) => switch (turns) {
      0 => (u, v),
      1 => (1 - v, u),
      2 => (1 - u, 1 - v),
      _ => (v, 1 - u),
    };
    final a = turn(box.left / w, 1 - box.top / h),
        b = turn(box.right / w, 1 - box.bottom / h);
    final left = math.min(a.$1, b.$1), top = math.min(a.$2, b.$2);
    return (
      left: left,
      top: top,
      width: (a.$1 - b.$1).abs(),
      height: (a.$2 - b.$2).abs(),
    );
  }

  /// BGRA → RGB with black rectangles over [areas] (normalised, top-left),
  /// grown by [margin] pixels.
  static Uint8List _burn(
    RenderedPage raster,
    List<({double left, double top, double width, double height})> areas, {
    required double margin,
  }) {
    final w = raster.width, h = raster.height;
    final rgb = Uint8List(w * h * 3);
    for (var i = 0, j = 0; j < rgb.length; i += 4, j += 3) {
      rgb[j] = raster.bgra[i + 2];
      rgb[j + 1] = raster.bgra[i + 1];
      rgb[j + 2] = raster.bgra[i];
    }
    for (final a in areas) {
      final x0 = math.max(0, (a.left * w - margin).floor()),
          x1 = math.min(w, ((a.left + a.width) * w + margin).ceil());
      final y0 = math.max(0, (a.top * h - margin).floor()),
          y1 = math.min(h, ((a.top + a.height) * h + margin).ceil());
      for (var y = y0; y < y1; y++) {
        rgb.fillRange((y * w + x0) * 3, (y * w + x1) * 3, 0);
      }
    }
    return rgb;
  }

  /// The words of a page's text with their boxes (page space).
  static List<(String, Box)> _words(PageText text) {
    final out = <(String, Box)>[];
    for (final m in RegExp(r'\S+').allMatches(text.text)) {
      final boxes = lineBoxes(text.charBoxes, m.start, m.end);
      if (boxes.length == 1) out.add((m[0]!, boxes.single));
    }
    return out;
  }

  static bool _overlap(Box a, Box b) =>
      a.left < b.right &&
      b.left < a.right &&
      a.bottom < b.top &&
      b.bottom < a.top;

  static String _squash(String s) => s.replaceAll(RegExp(r'\s+'), '');
}

// --- on pdfrx's worker ------------------------------------------------------

final _saved = BytesBuilder();

int _writeBlock(
  Pointer<fpdf.FPDF_FILEWRITE> self,
  Pointer<Void> data,
  int size,
) {
  _saved.add(Uint8List.fromList(data.cast<Uint8>().asTypedList(size)));
  return 1;
}

T _withMemoryDocument<T>(
  String path,
  T Function(fpdf.PDFium pdfium, fpdf.FPDF_DOCUMENT doc) body,
) {
  final pdfium = fpdf.getPdfium();
  return using((arena) {
    final bytes = File(path).readAsBytesSync();
    final buffer = arena<Uint8>(bytes.length)
      ..asTypedList(bytes.length).setAll(0, bytes);
    final doc = pdfium.FPDF_LoadMemDocument64(
      buffer.cast(),
      bytes.length,
      nullptr,
    );
    if (doc == nullptr) {
      throw StateError(
        'FPDF_LoadMemDocument64 failed: ${pdfium.FPDF_GetLastError()}',
      );
    }
    try {
      return body(pdfium, doc);
    } finally {
      pdfium.FPDF_CloseDocument(doc);
    }
  });
}

/// The document at [path] with every annotation removed, saved in full.
Uint8List _withoutAnnotationsOnWorker(String path) =>
    _withMemoryDocument(path, (pdfium, doc) {
      for (var i = 0; i < pdfium.FPDF_GetPageCount(doc); i++) {
        final page = pdfium.FPDF_LoadPage(doc, i);
        for (var a = pdfium.FPDFPage_GetAnnotCount(page) - 1; a >= 0; a--) {
          pdfium.FPDFPage_RemoveAnnot(page, a);
        }
        pdfium.FPDF_ClosePage(page);
      }
      final write =
          NativeCallable<
            Int Function(
              Pointer<fpdf.FPDF_FILEWRITE>,
              Pointer<Void>,
              UnsignedLong,
            )
          >.isolateLocal(_writeBlock, exceptionalReturn: 0);
      final fw = calloc<fpdf.FPDF_FILEWRITE>()
        ..ref.version = 1
        ..ref.WriteBlock = write.nativeFunction;
      try {
        _saved.clear();
        if (pdfium.FPDF_SaveAsCopy(doc, fw, fpdf.FPDF_NO_INCREMENTAL) == 0) {
          throw StateError('FPDF_SaveAsCopy failed');
        }
        return _saved.takeBytes();
      } finally {
        calloc.free(fw);
        write.close();
      }
    });

int _annotationCountOnWorker(String path) =>
    _withMemoryDocument(path, (pdfium, doc) {
      var count = 0;
      for (var i = 0; i < pdfium.FPDF_GetPageCount(doc); i++) {
        final page = pdfium.FPDF_LoadPage(doc, i);
        count += pdfium.FPDFPage_GetAnnotCount(page);
        pdfium.FPDF_ClosePage(page);
      }
      return count;
    });
