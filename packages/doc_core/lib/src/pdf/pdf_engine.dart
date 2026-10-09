import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as fpdf;
import 'package:pdfrx_engine/pdfrx_engine.dart';

/// The document core's PDF API (DK-0390): open, inspect, assemble, save,
/// render, text with character boxes, image objects.
///
/// **Threading.** PDFium is not thread-safe, and pdfrx runs every PDFium call
/// on its own worker isolate, one per Dart isolate that uses it. The viewer
/// uses pdfrx on the main isolate, so this API is called on the main isolate
/// too: everything goes through pdfrx (its API, or [PdfrxEntryFunctions.compute]
/// for raw PDFium calls), and all PDFium work in the app runs on that one
/// worker, one call at a time. The calling isolate itself never calls PDFium.
///
/// pdfrx must be initialised first: `pdfrxFlutterInitialize()` in the app,
/// `pdfrxInitialize()` in Dart tests.
///
/// Every call opens and closes the document it needs. Pages are 0-based.
/// Failures are [DocError]s, mapped to the error catalogue (UI spec §26.3).
abstract final class PdfEngine {
  /// Page count and page sizes.
  static Future<PdfInfo> inspect(String path, {String? password}) =>
      _withDocument(path, password, (doc) async {
        return PdfInfo(
          pages: [
            for (final p in doc.pages)
              PageInfo(
                width: p.width,
                height: p.height,
                quarterTurns: p.rotation.index,
              ),
          ],
        );
      });

  /// Writes a new PDF at [outPath] made of [pages], in order: merge, extract,
  /// reorder and rotate are all this. The sources are never modified, and the
  /// output is a full rewrite (FPDF_SaveAsCopy, never incremental).
  static Future<void> assemble(
    List<PageSource> pages,
    String outPath, {
    Map<String, String> passwords = const {},
  }) async {
    final open = <String, PdfDocument>{};
    PdfDocument? out;
    try {
      for (final path in {for (final p in pages) p.path}) {
        open[path] = await _open(path, passwords[path]);
      }
      out = await PdfDocument.createNew(sourceName: outPath);
      out.pages = [
        for (final s in pages)
          _page(
            open[s.path]!,
            s.page,
          ).rotatedBy(PdfPageRotation.values[s.addQuarterTurns % 4]),
      ];
      await _write(outPath, await out.encodePdf());
    } on DocError {
      rethrow;
    } catch (e) {
      throw DocError(DocErrorKind.unexpected, detail: '$e');
    } finally {
      await out?.dispose();
      for (final doc in open.values) {
        await doc.dispose();
      }
    }
  }

  /// The text of a page with one box per character (PDF points, origin
  /// bottom-left, as PDFium reports them). Search, redaction, compare and the
  /// OCR check read it.
  static Future<PageText> pageText(String path, int page, {String? password}) =>
      _withDocument(path, password, (doc) async {
        final raw = await _page(doc, page).loadText();
        return PageText(
          text: raw?.fullText ?? '',
          charBoxes: [
            for (final r in raw?.charRects ?? const <PdfRect>[])
              (left: r.left, top: r.top, right: r.right, bottom: r.bottom),
          ],
        );
      });

  /// Renders a page to BGRA pixels (white background), at [dpi] or scaled
  /// to [width] pixels; give exactly one.
  static Future<RenderedPage> render(
    String path,
    int page, {
    double? dpi,
    int? width,
    String? password,
  }) => _withDocument(path, password, (doc) async {
    assert((dpi == null) != (width == null), 'give dpi or width');
    final p = _page(doc, page);
    final scale = width != null ? width / p.width : dpi! / 72;
    final w = (p.width * scale).round();
    final height = (p.height * scale).round();
    final image = await p.render(
      fullWidth: w.toDouble(),
      fullHeight: height.toDouble(),
      width: w,
      height: height,
    );
    if (image == null) {
      throw DocError(
        DocErrorKind.unexpected,
        page: page,
        detail: 'render returned nothing',
      );
    }
    try {
      return RenderedPage(
        width: image.width,
        height: image.height,
        bgra: Uint8List.fromList(image.pixels),
      );
    } finally {
      image.dispose();
    }
  });

  /// The image objects on a page: where each sits and its pixel size.
  static Future<List<ImageObject>> images(
    String path,
    int page, {
    String? password,
  }) async {
    await _withDocument(
      path,
      password,
      (doc) async => _page(doc, page),
    ); // validates path, password, page
    return PdfrxEntryFunctions.instance.compute(_imagesOnWorker, (
      path,
      password,
      page,
    ));
  }

  /// Whether the page shows text in a font that isn't embedded: PDF/A needs
  /// every visible font embedded (DK-0395). Goes character by character, so
  /// text in form XObjects (stamps, overlays) counts too; invisible text (an
  /// OCR layer, rendering mode 3) doesn't.
  static Future<bool> usesUnembeddedFonts(
    String path,
    int page, {
    String? password,
  }) async {
    await _withDocument(path, password, (doc) async => _page(doc, page));
    return PdfrxEntryFunctions.instance.compute(_unembeddedOnWorker, (
      path,
      password,
      page,
    ));
  }

  /// Every character of a page with its box, baseline, font size (points)
  /// and boldness, for layout analysis
  /// ([PdfStructure]).
  static Future<List<StyledChar>> styledChars(
    String path,
    int page, {
    String? password,
  }) async {
    await _withDocument(path, password, (doc) async => _page(doc, page));
    return PdfrxEntryFunctions.instance.compute(_styledCharsOnWorker, (
      path,
      password,
      page,
    ));
  }

  static Future<T> _withDocument<T>(
    String path,
    String? password,
    Future<T> Function(PdfDocument) body,
  ) async {
    final doc = await _open(path, password);
    try {
      return await body(doc);
    } on DocError {
      rethrow;
    } catch (e) {
      throw DocError(DocErrorKind.unexpected, detail: '$e');
    } finally {
      await doc.dispose();
    }
  }

  static Future<PdfDocument> _open(String path, String? password) async {
    try {
      return await PdfDocument.openFile(
        path,
        // pdfrx asks again until the provider returns null: offer the
        // password once, so a wrong one fails instead of looping.
        passwordProvider: password == null
            ? null
            : () {
                final once = password;
                password = null;
                return once;
              },
        firstAttemptByEmptyPassword: true,
      );
    } on PdfPasswordException {
      throw DocError(DocErrorKind.locked, detail: path);
    } on PdfException catch (e) {
      throw DocError(
        _kindOf(e.errorCode),
        detail: '${e.message} ($path)',
        code: e.errorCode,
      );
    }
  }

  static PdfPage _page(PdfDocument doc, int page) {
    if (page < 0 || page >= doc.pages.length) {
      throw DocError(
        DocErrorKind.unexpected,
        page: page,
        detail: 'no page $page of ${doc.pages.length}',
      );
    }
    return doc.pages[page];
  }

  static Future<void> _write(String outPath, Uint8List bytes) async {
    try {
      await File(outPath).writeAsBytes(bytes, flush: true);
    } on FileSystemException catch (e) {
      // ENOSPC (28 on Linux/Android/iOS, 112 on Windows).
      final full = e.osError?.errorCode == 28 || e.osError?.errorCode == 112;
      throw DocError(
        full ? DocErrorKind.notEnoughStorage : DocErrorKind.unexpected,
        detail: '$e',
      );
    }
  }

  /// PDFium's FPDF_GetLastError codes.
  static DocErrorKind _kindOf(int? code) => switch (code) {
    4 => DocErrorKind.locked, // FPDF_ERR_PASSWORD
    2 || 3 => DocErrorKind.damaged, // FPDF_ERR_FILE, FPDF_ERR_FORMAT
    _ => DocErrorKind.unexpected,
  };
}

/// Runs on pdfrx's PDFium worker (via compute): raw PDFium calls.
/// Runs [body] on one page of a document loaded by raw PDFium. Call it only
/// on pdfrx's worker (via compute).
T _onPage<T>(
  (String, String?, int) message,
  T Function(fpdf.PDFium pdfium, fpdf.FPDF_PAGE page, Arena arena) body,
) {
  final (path, password, pageIndex) = message;
  final pdfium = fpdf.getPdfium();
  return using((arena) {
    // From memory, not FPDF_LoadDocument(path): PDFium's path handling isn't
    // UTF-8-safe everywhere, and our names have ß, ü and –. The buffer must
    // outlive the document, which the arena guarantees.
    final bytes = File(path).readAsBytesSync();
    final buffer = arena<Uint8>(bytes.length);
    buffer.asTypedList(bytes.length).setAll(0, bytes);
    final doc = pdfium.FPDF_LoadMemDocument64(
      buffer.cast(),
      bytes.length,
      password == null
          ? nullptr
          : password.toNativeUtf8(allocator: arena).cast(),
    );
    if (doc == nullptr) {
      throw StateError(
        'FPDF_LoadMemDocument64 failed: ${pdfium.FPDF_GetLastError()}',
      );
    }
    final page = pdfium.FPDF_LoadPage(doc, pageIndex);
    try {
      return body(pdfium, page, arena);
    } finally {
      pdfium.FPDF_ClosePage(page);
      pdfium.FPDF_CloseDocument(doc);
    }
  });
}

/// On pdfrx's worker: the page's image objects.
List<ImageObject> _imagesOnWorker((String, String?, int) message) =>
    _onPage(message, (pdfium, page, arena) {
      final found = <ImageObject>[];
      final left = arena<Float>(),
          bottom = arena<Float>(),
          right = arena<Float>(),
          top = arena<Float>();
      final w = arena<UnsignedInt>(), h = arena<UnsignedInt>();
      for (var i = 0; i < pdfium.FPDFPage_CountObjects(page); i++) {
        final obj = pdfium.FPDFPage_GetObject(page, i);
        if (pdfium.FPDFPageObj_GetType(obj) != fpdf.FPDF_PAGEOBJ_IMAGE) {
          continue;
        }
        pdfium.FPDFPageObj_GetBounds(obj, left, bottom, right, top);
        pdfium.FPDFImageObj_GetImagePixelSize(obj, w, h);
        found.add(
          ImageObject(
            index: i,
            box: (
              left: left.value,
              top: top.value,
              right: right.value,
              bottom: bottom.value,
            ),
            pixelWidth: w.value,
            pixelHeight: h.value,
          ),
        );
      }
      return found;
    });

/// On pdfrx's worker: whether a visible character's font isn't embedded.
bool _unembeddedOnWorker((String, String?, int) message) =>
    _onPage(message, (pdfium, page, arena) {
      final text = pdfium.FPDFText_LoadPage(page);
      try {
        final seen = <int>{};
        for (var i = 0; i < pdfium.FPDFText_CountChars(text); i++) {
          final obj = pdfium.FPDFText_GetTextObject(text, i);
          if (obj == nullptr || !seen.add(obj.address)) continue;
          if (pdfium.FPDFTextObj_GetTextRenderMode(obj) ==
              fpdf.FPDF_TEXT_RENDERMODE.FPDF_TEXTRENDERMODE_INVISIBLE) {
            continue;
          }
          final font = pdfium.FPDFTextObj_GetFont(obj);
          if (font != nullptr && pdfium.FPDFFont_GetIsEmbedded(font) == 0) {
            return true;
          }
        }
        return false;
      } finally {
        pdfium.FPDFText_ClosePage(text);
      }
    });

/// On pdfrx's worker: every character with its box, font size and weight.
/// Line breaks and other control characters are left out: lines come from
/// the baselines. Spaces stay, PDFium's generated ones included: they mark
/// the word gaps more reliably than tight glyph boxes.
List<StyledChar> _styledCharsOnWorker((String, String?, int) message) =>
    _onPage(message, (pdfium, page, arena) {
      final text = pdfium.FPDFText_LoadPage(page);
      try {
        final l = arena<Double>(), r = arena<Double>();
        final b = arena<Double>(), t = arena<Double>();
        final x = arena<Double>(), y = arena<Double>();
        final name = arena<Uint8>(128);
        final flags = arena<Int>();
        final chars = <StyledChar>[];
        for (var i = 0; i < pdfium.FPDFText_CountChars(text); i++) {
          final unicode = pdfium.FPDFText_GetUnicode(text, i);
          if (unicode < 0x20) {
            continue;
          }
          pdfium.FPDFText_GetCharBox(text, i, l, r, b, t);
          pdfium.FPDFText_GetCharOrigin(text, i, x, y);
          final length = pdfium.FPDFText_GetFontInfo(
            text,
            i,
            name.cast(),
            128,
            flags,
          );
          final font = length > 1
              ? String.fromCharCodes(name.asTypedList(length - 1))
              : '';
          final weight = pdfium.FPDFText_GetFontWeight(text, i);
          chars.add(
            StyledChar(
              String.fromCharCode(unicode),
              (left: l.value, top: t.value, right: r.value, bottom: b.value),
              baseline: y.value,
              fontSize: pdfium.FPDFText_GetFontSize(text, i),
              // The weight when the font says; otherwise its name, or the
              // ForceBold flag (bit 19).
              bold:
                  weight >= 600 ||
                  font.toLowerCase().contains('bold') ||
                  flags.value & 0x40000 != 0,
            ),
          );
        }
        return chars;
      } finally {
        pdfium.FPDFText_ClosePage(text);
      }
    });

/// A character as PDFium places it.
class StyledChar {
  const StyledChar(
    this.char,
    this.box, {
    required this.baseline,
    required this.fontSize,
    this.bold = false,
  });
  final String char;

  /// The glyph's tight box: tops and bottoms vary per glyph.
  final Box box;

  /// The text line's y (the character's origin): the same for every glyph
  /// on a line.
  final double baseline;
  final double fontSize;
  final bool bold;
}

/// A box in PDF points.
typedef Box = ({double left, double top, double right, double bottom});

class PdfInfo {
  const PdfInfo({required this.pages});
  final List<PageInfo> pages;
  int get pageCount => pages.length;
}

class PageInfo {
  const PageInfo({
    required this.width,
    required this.height,
    required this.quarterTurns,
  });

  /// In points, as displayed (after the page's rotation).
  final double width, height;

  /// The page's /Rotate, in quarter turns clockwise.
  final int quarterTurns;
}

/// One page of an [PdfEngine.assemble] output.
class PageSource {
  const PageSource(this.path, this.page, {this.addQuarterTurns = 0});
  final String path;
  final int page;

  /// Extra clockwise quarter turns on top of the page's own rotation.
  final int addQuarterTurns;
}

class PageText {
  const PageText({required this.text, required this.charBoxes});
  final String text;

  /// One box per character of [text].
  final List<Box> charBoxes;
}

class RenderedPage {
  const RenderedPage({
    required this.width,
    required this.height,
    required this.bgra,
  });
  final int width, height;
  final Uint8List bgra;

  /// The same pixels as RGBA, as image encoders and the `pdf` package want them.
  Uint8List get rgba {
    final out = Uint8List.fromList(bgra);
    for (var i = 0; i < out.length; i += 4) {
      out[i] = bgra[i + 2];
      out[i + 2] = bgra[i];
    }
    return out;
  }
}

class ImageObject {
  const ImageObject({
    required this.index,
    required this.box,
    required this.pixelWidth,
    required this.pixelHeight,
  });

  /// The object's index on its page.
  final int index;
  final Box box;
  final int pixelWidth, pixelHeight;
}

/// The error catalogue's situations (UI spec §26.3) that the PDF layer can
/// detect; the UI picks the message and the action.
enum DocErrorKind {
  locked,
  damaged,
  notEnoughStorage,
  tooLarge,
  unsupportedForm,
  cancelled,
  unexpected,
}

class DocError implements Exception {
  const DocError(
    this.kind, {
    this.page,
    this.detail = '',
    this.code,
    this.bytes,
  });
  final DocErrorKind kind;

  /// The 0-based page the failure happened on, if known ("on page 14").
  final int? page;

  /// For logs and the user-sent report; never shown as the message.
  final String detail;

  /// PDFium's error code, if any.
  final int? code;

  /// Not enough storage: the bytes the job needs (DK-0020).
  final int? bytes;

  @override
  String toString() =>
      'DocError(${kind.name}${page == null ? '' : ', page $page'}: $detail)';
}
