import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:pdfium_dart/pdfium_dart.dart' as fpdf;
import 'package:pdfrx_engine/pdfrx_engine.dart' show PdfrxEntryFunctions;

import 'pdf_engine.dart';
import 'pdfium_raw.dart';

/// A point in page space (points, origin bottom-left, the page unrotated).
typedef PagePoint = ({double x, double y});

/// A text-markup quad: the four corners of a line of selected text, in the
/// PDF order (top-left, top-right, bottom-left, bottom-right).
typedef MarkupQuad = (PagePoint, PagePoint, PagePoint, PagePoint);

/// The text-markup kinds (the edit mode's Highlight, Underline, Strike).
enum MarkupKind { highlight, underline, strikeOut, squiggly }

/// The shape kinds with their own PDF annotation.
enum ShapeKind { square, circle }

/// An annotation as Dokulo edits it (DK-0312): standard PDF annotations, so
/// other readers show them. Colours are ARGB; the alpha is the opacity.
sealed class PdfAnnot {
  const PdfAnnot({required this.color, this.note = ''});

  final int color;

  /// The annotation's text (`Contents`): a note's text, a comment.
  final String note;

  /// Where it sits on the page (its `Rect`).
  Box get bounds;
}

/// Pen strokes; also lines and arrows (a stroke of two points each), which
/// every reader draws the same way.
final class InkAnnot extends PdfAnnot {
  const InkAnnot(
    this.strokes, {
    required this.width,
    required super.color,
    super.note,
  });
  final List<List<PagePoint>> strokes;
  final double width;

  @override
  Box get bounds =>
      _boundsOf([for (final s in strokes) ...s], pad: width / 2 + 1);
}

/// Highlight, underline, strike-through or squiggly over text.
final class MarkupAnnot extends PdfAnnot {
  const MarkupAnnot(this.kind, this.quads, {required super.color, super.note});
  final MarkupKind kind;
  final List<MarkupQuad> quads;

  @override
  Box get bounds => _boundsOf([
    for (final q in quads) ...[q.$1, q.$2, q.$3, q.$4],
  ]);
}

/// A rectangle or an ellipse, with an optional [fill].
final class ShapeAnnot extends PdfAnnot {
  const ShapeAnnot(
    this.kind,
    this.rect, {
    required this.width,
    required super.color,
    this.fill,
    super.note,
  });
  final ShapeKind kind;
  final Box rect;
  final double width;
  final int? fill;

  @override
  Box get bounds => rect;
}

/// A text box on the page.
final class FreeTextAnnot extends PdfAnnot {
  const FreeTextAnnot(
    this.rect,
    this.text, {
    required this.fontSize,
    required super.color,
  });
  final Box rect;
  final String text;
  final double fontSize;

  @override
  String get note => text;

  @override
  Box get bounds => rect;
}

/// A sticky note: the icon at [at] (its top-left corner) and its [note].
final class NoteAnnot extends PdfAnnot {
  const NoteAnnot(this.at, {required super.note, required super.color});
  final PagePoint at;

  /// The icon's size, as readers draw it.
  static const iconSize = 24.0;

  @override
  Box get bounds =>
      (left: at.x, top: at.y, right: at.x + iconSize, bottom: at.y - iconSize);
}

/// A signature (DK-0328): the signature's image in [rect], and the date
/// ([date], already in the user's format) to its right, grouped with it.
/// Written into the page's content (an image object and a text object), so
/// every reader shows it and it prints; it isn't an annotation once saved.
final class StampAnnot extends PdfAnnot {
  const StampAnnot(this.rect, this.png, {this.date, this.dateSize = 10})
    : super(color: 0xFF000000);

  final Box rect;

  /// The signature as PNG (transparent around the ink).
  final Uint8List png;
  final String? date;

  /// The date's font size, in points.
  final double dateSize;

  /// The gap between the signature and the date, in points.
  static const dateGap = 6.0;

  /// The date's box: right of the signature, its baseline near the
  /// signature's bottom (Helvetica's digits are about 0.55 em wide).
  Box? get dateBox => switch (date) {
    final d? => (
      left: rect.right + dateGap,
      top: rect.bottom + dateSize * 1.2,
      right: rect.right + dateGap + d.length * dateSize * 0.56,
      bottom: rect.bottom,
    ),
    null => null,
  };

  @override
  Box get bounds => switch (dateBox) {
    final d? => (
      left: rect.left,
      top: rect.top > d.top ? rect.top : d.top,
      right: d.right,
      bottom: rect.bottom,
    ),
    null => rect,
  };
}

/// An annotation Dokulo doesn't edit (a link, a stamp, a form widget): kept
/// as it is, shown for hit testing only.
final class OtherAnnot extends PdfAnnot {
  const OtherAnnot(this.subtype, this.rect) : super(color: 0);
  final int subtype;
  final Box rect;

  @override
  Box get bounds => rect;
}

/// An annotation read from a page, with its index there (what
/// [PageAnnotEdits.remove] names).
typedef PageAnnot = ({int index, PdfAnnot annot});

/// The edits to one page: annotations to [remove] (by index, as read) and
/// to [add]. An edited annotation is removed and added again.
class PageAnnotEdits {
  const PageAnnotEdits({this.remove = const {}, this.add = const []});
  final Set<int> remove;
  final List<PdfAnnot> add;
}

/// Reads and writes page annotations through PDFium (DK-0312; Technology
/// plan: FPDFPage_CreateAnnot, FPDFAnnot_SetAttachmentPoints, ink strokes), on
/// pdfrx's worker like the rest of [PdfEngine].
abstract final class PdfAnnotations {
  /// The annotations on [page], in the page's order.
  static Future<List<PageAnnot>> read(
    String path,
    int page, {
    String? password,
  }) async {
    await PdfEngine.inspect(path, password: password); // password, damage
    return PdfrxEntryFunctions.instance.compute(_readOnWorker, (
      path,
      password,
      page,
    ));
  }

  /// Writes [path] with [edits] (by page) to [outPath] as a full rewrite.
  /// An index that isn't on the page is a [DocError] (unexpected), and
  /// nothing is written.
  static Future<void> apply(
    String path,
    String outPath,
    Map<int, PageAnnotEdits> edits, {
    String? password,
  }) async {
    await PdfEngine.inspect(path, password: password);
    final (bytes, error) = await PdfrxEntryFunctions.instance.compute(
      _applyOnWorker,
      (path, password, edits),
    );
    // A refusal comes back as a value: an exception would arrive wrapped.
    if (error != null) throw error;
    await File(outPath).writeAsBytes(bytes!, flush: true);
  }
}

Box _boundsOf(List<PagePoint> pts, {double pad = 0}) {
  if (pts.isEmpty) return (left: 0, top: 0, right: 0, bottom: 0);
  var l = pts.first.x, r = l, b = pts.first.y, t = b;
  for (final p in pts) {
    if (p.x < l) l = p.x;
    if (p.x > r) r = p.x;
    if (p.y < b) b = p.y;
    if (p.y > t) t = p.y;
  }
  return (left: l - pad, top: t + pad, right: r + pad, bottom: b - pad);
}

// ---------------------------------------------------------------------------
// On pdfrx's worker.

String _string(
  fpdf.PDFium pdfium,
  fpdf.FPDF_ANNOTATION a,
  String key,
  Arena arena,
) {
  final k = key.toNativeUtf8(allocator: arena).cast<Char>();
  final bytes = pdfium.FPDFAnnot_GetStringValue(a, k, nullptr, 0);
  if (bytes <= 2) return '';
  final buffer = arena<Uint16>(bytes ~/ 2);
  pdfium.FPDFAnnot_GetStringValue(a, k, buffer.cast(), bytes);
  return String.fromCharCodes(buffer.asTypedList(bytes ~/ 2 - 1));
}

int? _colorOf(
  fpdf.PDFium pdfium,
  fpdf.FPDF_ANNOTATION a,
  fpdf.FPDFANNOT_COLORTYPE type,
  Arena arena,
) {
  final r = arena<UnsignedInt>(),
      g = arena<UnsignedInt>(),
      b = arena<UnsignedInt>(),
      al = arena<UnsignedInt>();
  if (pdfium.FPDFAnnot_GetColor(a, type, r, g, b, al) == 0) return null;
  return (al.value & 0xFF) << 24 |
      (r.value & 0xFF) << 16 |
      (g.value & 0xFF) << 8 |
      (b.value & 0xFF);
}

double _width(fpdf.PDFium pdfium, fpdf.FPDF_ANNOTATION a, Arena arena) {
  final h = arena<Float>(), v = arena<Float>(), w = arena<Float>();
  return pdfium.FPDFAnnot_GetBorder(a, h, v, w) == 0 ? 1 : w.value;
}

const _markupSubtypes = {
  fpdf.FPDF_ANNOT_HIGHLIGHT: MarkupKind.highlight,
  fpdf.FPDF_ANNOT_UNDERLINE: MarkupKind.underline,
  fpdf.FPDF_ANNOT_STRIKEOUT: MarkupKind.strikeOut,
  fpdf.FPDF_ANNOT_SQUIGGLY: MarkupKind.squiggly,
};

List<PageAnnot> _readOnWorker(
  (String, String?, int) m,
) => withRawDocument(m.$1, m.$2, (pdfium, doc, arena) {
  final page = pdfium.FPDF_LoadPage(doc, m.$3);
  final found = <PageAnnot>[];
  final rect = arena<fpdf.FS_RECTF>();
  final quad = arena<fpdf.FS_QUADPOINTSF>();
  try {
    for (var i = 0; i < pdfium.FPDFPage_GetAnnotCount(page); i++) {
      final a = pdfium.FPDFPage_GetAnnot(page, i);
      try {
        final subtype = pdfium.FPDFAnnot_GetSubtype(a);
        pdfium.FPDFAnnot_GetRect(a, rect);
        final box = (
          left: rect.ref.left,
          top: rect.ref.top,
          right: rect.ref.right,
          bottom: rect.ref.bottom,
        );
        final color =
            _colorOf(
              pdfium,
              a,
              fpdf.FPDFANNOT_COLORTYPE.FPDFANNOT_COLORTYPE_Color,
              arena,
            ) ??
            0xFF000000;
        final note = _string(pdfium, a, 'Contents', arena);
        final PdfAnnot annot;
        if (subtype == fpdf.FPDF_ANNOT_INK) {
          final strokes = <List<PagePoint>>[];
          for (var s = 0; s < pdfium.FPDFAnnot_GetInkListCount(a); s++) {
            final n = pdfium.FPDFAnnot_GetInkListPath(a, s, nullptr, 0);
            final pts = arena<fpdf.FS_POINTF>(n);
            pdfium.FPDFAnnot_GetInkListPath(a, s, pts, n);
            strokes.add([
              for (var p = 0; p < n; p++) (x: pts[p].x, y: pts[p].y),
            ]);
          }
          annot = InkAnnot(
            strokes,
            width: _width(pdfium, a, arena),
            color: color,
            note: note,
          );
        } else if (_markupSubtypes[subtype] case final kind?) {
          final quads = <MarkupQuad>[];
          for (var q = 0; q < pdfium.FPDFAnnot_CountAttachmentPoints(a); q++) {
            pdfium.FPDFAnnot_GetAttachmentPoints(a, q, quad);
            final r = quad.ref;
            quads.add((
              (x: r.x1, y: r.y1),
              (x: r.x2, y: r.y2),
              (x: r.x3, y: r.y3),
              (x: r.x4, y: r.y4),
            ));
          }
          annot = MarkupAnnot(kind, quads, color: color, note: note);
        } else if (subtype == fpdf.FPDF_ANNOT_SQUARE ||
            subtype == fpdf.FPDF_ANNOT_CIRCLE) {
          annot = ShapeAnnot(
            subtype == fpdf.FPDF_ANNOT_SQUARE
                ? ShapeKind.square
                : ShapeKind.circle,
            box,
            width: _width(pdfium, a, arena),
            color: color,
            // Without /IC PDFium reports the appearance's colour: no fill.
            fill:
                pdfium.FPDFAnnot_HasKey(
                      a,
                      'IC'.toNativeUtf8(allocator: arena).cast(),
                    ) ==
                    0
                ? null
                : _colorOf(
                    pdfium,
                    a,
                    fpdf.FPDFANNOT_COLORTYPE.FPDFANNOT_COLORTYPE_InteriorColor,
                    arena,
                  ),
            note: note,
          );
        } else if (subtype == fpdf.FPDF_ANNOT_FREETEXT) {
          annot = FreeTextAnnot(
            box,
            note,
            fontSize: _fontSizeOf(_string(pdfium, a, 'DA', arena)),
            color: _daColor(_string(pdfium, a, 'DA', arena)),
          );
        } else if (subtype == fpdf.FPDF_ANNOT_TEXT) {
          annot = NoteAnnot(
            (x: box.left, y: box.top),
            note: note,
            color: color,
          );
        } else {
          annot = OtherAnnot(subtype, box);
        }
        found.add((index: i, annot: annot));
      } finally {
        pdfium.FPDFPage_CloseAnnot(a);
      }
    }
    return found;
  } finally {
    pdfium.FPDF_ClosePage(page);
  }
});

/// The font size in a default-appearance string ("/Helv 12 Tf 0 0 0 rg").
double _fontSizeOf(String da) =>
    double.tryParse(RegExp(r'([\d.]+)\s+Tf').firstMatch(da)?.group(1) ?? '') ??
    12;

/// The fill colour in a default-appearance string, as ARGB.
int _daColor(String da) {
  final m = RegExp(r'([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+rg').firstMatch(da);
  if (m == null) return 0xFF000000;
  int c(int i) => (double.parse(m.group(i)!) * 255).round().clamp(0, 255);
  return 0xFF000000 | c(1) << 16 | c(2) << 8 | c(3);
}

(Uint8List?, DocError?) _applyOnWorker(
  (String, String?, Map<int, PageAnnotEdits>) m,
) {
  try {
    return (_apply(m), null);
  } on DocError catch (e) {
    return (null, e);
  }
}

Uint8List _apply((String, String?, Map<int, PageAnnotEdits>) m) {
  final (path, password, edits) = m;
  return withRawDocument(path, password, (pdfium, doc, arena) {
    for (final MapEntry(key: p, value: e) in edits.entries) {
      if (p < 0 || p >= pdfium.FPDF_GetPageCount(doc)) {
        throw DocError(DocErrorKind.unexpected, page: p, detail: 'no page $p');
      }
      final page = pdfium.FPDF_LoadPage(doc, p);
      try {
        final count = pdfium.FPDFPage_GetAnnotCount(page);
        // From the last index down, so the earlier indices stay valid.
        for (final i in e.remove.toList()..sort((a, b) => b.compareTo(a))) {
          if (i < 0 ||
              i >= count ||
              pdfium.FPDFPage_RemoveAnnot(page, i) == 0) {
            throw DocError(
              DocErrorKind.unexpected,
              page: p,
              detail: 'no annotation $i',
            );
          }
        }
        for (final a in e.add) {
          if (a is StampAnnot) {
            _placeStamp(pdfium, doc, page, a, arena);
          } else {
            _create(pdfium, page, a, arena);
          }
        }
        if (e.add.any((a) => a is StampAnnot) &&
            pdfium.FPDFPage_GenerateContent(page) == 0) {
          throw DocError(
            DocErrorKind.unexpected,
            page: p,
            detail: 'FPDFPage_GenerateContent failed',
          );
        }
      } finally {
        pdfium.FPDF_ClosePage(page);
      }
    }
    return saveRawDocument(pdfium, doc);
  });
}

/// A signature into the page's content: its image (BGRA, so the
/// transparency stays) scaled to [StampAnnot.rect], then the date.
void _placeStamp(
  fpdf.PDFium pdfium,
  fpdf.FPDF_DOCUMENT doc,
  fpdf.FPDF_PAGE page,
  StampAnnot stamp,
  Arena arena,
) {
  final decoded = img.decodePng(stamp.png);
  if (decoded == null) {
    throw const DocError(DocErrorKind.unexpected, detail: 'not a PNG');
  }
  final rgba = decoded.convert(format: img.Format.uint8, numChannels: 4);
  final w = rgba.width, h = rgba.height;
  final bgra = arena<Uint8>(w * h * 4);
  final pixels = bgra.asTypedList(w * h * 4);
  var i = 0;
  for (final px in rgba) {
    pixels[i++] = px.b.toInt();
    pixels[i++] = px.g.toInt();
    pixels[i++] = px.r.toInt();
    pixels[i++] = px.a.toInt();
  }
  final bitmap = pdfium.FPDFBitmap_CreateEx(
    w,
    h,
    fpdf.FPDFBitmap_BGRA,
    bgra.cast(),
    w * 4,
  );
  final obj = pdfium.FPDFPageObj_NewImageObj(doc);
  final pages = arena<fpdf.FPDF_PAGE>()..value = page;
  try {
    final r = stamp.rect;
    if (pdfium.FPDFImageObj_SetBitmap(pages, 1, obj, bitmap) == 0 ||
        pdfium.FPDFImageObj_SetMatrix(
              obj,
              r.right - r.left,
              0,
              0,
              r.top - r.bottom,
              r.left,
              r.bottom,
            ) ==
            0) {
      pdfium.FPDFPageObj_Destroy(obj);
      throw const DocError(
        DocErrorKind.unexpected,
        detail: 'the signature image could not be set',
      );
    }
    pdfium.FPDFPage_InsertObject(page, obj);
  } finally {
    pdfium.FPDFBitmap_Destroy(bitmap);
  }
  if (stamp.dateBox case final box?) {
    final text = pdfium.FPDFPageObj_NewTextObj(
      doc,
      'Helvetica'.toNativeUtf8(allocator: arena).cast(),
      stamp.dateSize,
    );
    pdfium.FPDFText_SetText(
      text,
      stamp.date!.toNativeUtf16(allocator: arena).cast(),
    );
    pdfium.FPDFPageObj_SetFillColor(text, 0, 0, 0, 255);
    // Its baseline a little above the box's bottom (descenders).
    pdfium.FPDFPageObj_Transform(
      text,
      1,
      0,
      0,
      1,
      box.left,
      box.bottom + stamp.dateSize * 0.2,
    );
    pdfium.FPDFPage_InsertObject(page, text);
  }
}

void _setColor(
  fpdf.PDFium pdfium,
  fpdf.FPDF_ANNOTATION a,
  fpdf.FPDFANNOT_COLORTYPE type,
  int argb,
) => pdfium.FPDFAnnot_SetColor(
  a,
  type,
  argb >> 16 & 0xFF,
  argb >> 8 & 0xFF,
  argb & 0xFF,
  argb >> 24 & 0xFF,
);

void _create(
  fpdf.PDFium pdfium,
  fpdf.FPDF_PAGE page,
  PdfAnnot annot,
  Arena arena,
) {
  final subtype = switch (annot) {
    InkAnnot() => fpdf.FPDF_ANNOT_INK,
    MarkupAnnot(:final kind) =>
      _markupSubtypes.entries.firstWhere((e) => e.value == kind).key,
    ShapeAnnot(kind: ShapeKind.square) => fpdf.FPDF_ANNOT_SQUARE,
    ShapeAnnot(kind: ShapeKind.circle) => fpdf.FPDF_ANNOT_CIRCLE,
    FreeTextAnnot() => fpdf.FPDF_ANNOT_FREETEXT,
    NoteAnnot() => fpdf.FPDF_ANNOT_TEXT,
    OtherAnnot() => throw const DocError(
      DocErrorKind.unexpected,
      detail: 'other annotations are kept, not created',
    ),
    StampAnnot() => throw const DocError(
      DocErrorKind.unexpected,
      detail: 'a signature goes into the content, not an annotation',
    ),
  };
  final a = pdfium.FPDFPage_CreateAnnot(page, subtype);
  if (a == nullptr) {
    throw DocError(
      DocErrorKind.unexpected,
      detail: 'FPDFPage_CreateAnnot($subtype) failed',
    );
  }
  try {
    final color = fpdf.FPDFANNOT_COLORTYPE.FPDFANNOT_COLORTYPE_Color;
    final b = annot.bounds;
    final rect = arena<fpdf.FS_RECTF>()
      ..ref.left = b.left
      ..ref.top = b.top
      ..ref.right = b.right
      ..ref.bottom = b.bottom;
    pdfium.FPDFAnnot_SetRect(a, rect);
    // Print with the page (PDF annotation flag 3).
    pdfium.FPDFAnnot_SetFlags(a, fpdf.FPDF_ANNOT_FLAG_PRINT);
    if (annot.note.isNotEmpty && annot is! FreeTextAnnot) {
      _setString(pdfium, a, 'Contents', annot.note, arena);
    }
    switch (annot) {
      case InkAnnot(:final strokes, :final width):
        _setColor(pdfium, a, color, annot.color);
        pdfium.FPDFAnnot_SetBorder(a, 0, 0, width);
        for (final s in strokes) {
          final pts = arena<fpdf.FS_POINTF>(s.length);
          for (var i = 0; i < s.length; i++) {
            pts[i]
              ..x = s[i].x
              ..y = s[i].y;
          }
          pdfium.FPDFAnnot_AddInkStroke(a, pts, s.length);
        }
      case MarkupAnnot(:final kind, :final quads):
        _setColor(pdfium, a, color, annot.color);
        final q = arena<fpdf.FS_QUADPOINTSF>();
        for (final (p1, p2, p3, p4) in quads) {
          q.ref
            ..x1 = p1.x
            ..y1 = p1.y
            ..x2 = p2.x
            ..y2 = p2.y
            ..x3 = p3.x
            ..y3 = p3.y
            ..x4 = p4.x
            ..y4 = p4.y;
          pdfium.FPDFAnnot_AppendAttachmentPoints(a, q);
        }
        if (_lineAppearance(kind, quads, annot.color) case final ap?) {
          pdfium.FPDFAnnot_SetAP(
            a,
            fpdf.FPDF_ANNOT_APPEARANCEMODE_NORMAL,
            ap.toNativeUtf16(allocator: arena).cast(),
          );
        }
      case ShapeAnnot(:final width, :final fill):
        _setColor(pdfium, a, color, annot.color);
        pdfium.FPDFAnnot_SetBorder(a, 0, 0, width);
        if (fill != null) {
          _setColor(
            pdfium,
            a,
            fpdf.FPDFANNOT_COLORTYPE.FPDFANNOT_COLORTYPE_InteriorColor,
            fill,
          );
        }
      case FreeTextAnnot(:final text, :final fontSize):
        double c(int shift) => (annot.color >> shift & 0xFF) / 255;
        _setString(pdfium, a, 'Contents', text, arena);
        _setString(
          pdfium,
          a,
          'DA',
          '/Helv ${fontSize.toStringAsFixed(1)} Tf ${c(16).toStringAsFixed(3)} ${c(8).toStringAsFixed(3)} ${c(0).toStringAsFixed(3)} rg',
          arena,
        );
      case NoteAnnot():
        _setColor(pdfium, a, color, annot.color);
      case OtherAnnot() || StampAnnot():
        break;
    }
  } finally {
    pdfium.FPDFPage_CloseAnnot(a);
  }
}

/// An underline's or strike's own appearance when a quad isn't upright
/// (DK-1138): PDFium draws them across the page whatever the corner order,
/// so text set sideways or upside down gets its line along the quad, from
/// the lower corners (underline) or the sides' midpoints (strike). Null for
/// upright quads and other kinds: PDFium's appearance is right there.
String? _lineAppearance(MarkupKind kind, List<MarkupQuad> quads, int argb) {
  if (kind != MarkupKind.underline && kind != MarkupKind.strikeOut) {
    return null;
  }
  bool upright(MarkupQuad q) => q.$3.y == q.$4.y && q.$3.x < q.$4.x;
  if (quads.every(upright)) return null;
  String n(double v) => v.toStringAsFixed(2);
  double c(int shift) => (argb >> shift & 0xFF) / 255;
  final out = StringBuffer('${n(c(16))} ${n(c(8))} ${n(c(0))} RG 1 w\n');
  for (final (p1, p2, p3, p4) in quads) {
    final (PagePoint a, PagePoint b) = switch (kind) {
      MarkupKind.underline => (p3, p4),
      _ => (
        (x: (p1.x + p3.x) / 2, y: (p1.y + p3.y) / 2),
        (x: (p2.x + p4.x) / 2, y: (p2.y + p4.y) / 2),
      ),
    };
    out.write('${n(a.x)} ${n(a.y)} m ${n(b.x)} ${n(b.y)} l S\n');
  }
  return out.toString();
}

void _setString(
  fpdf.PDFium pdfium,
  fpdf.FPDF_ANNOTATION a,
  String key,
  String value,
  Arena arena,
) => pdfium.FPDFAnnot_SetStringValue(
  a,
  key.toNativeUtf8(allocator: arena).cast(),
  value.toNativeUtf16(allocator: arena).cast(),
);
