import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:doc_core/doc_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../components/dk_editor_bars.dart';
import '../../theme/dk_tokens.dart';
import 'annotation_editor.dart';

/// How new annotations look; the tools' options sheets (DK-0314…0320) set
/// them.
class EditStyle {
  const EditStyle({
    this.penColor = 0xFF14171C,
    this.penWidth = 2,
    this.highlighterColor = 0x80FFEB3B,
    this.highlighterWidth = 14,
    this.shape = ShapeKind.square,
    this.shapeColor = 0xFFE53935,
    this.shapeWidth = 2,
    this.textColor = 0xFF14171C,
    this.fontSize = 14,
    this.noteColor = 0xFFFFC107,
  });

  final int penColor, highlighterColor, shapeColor, textColor, noteColor;
  final double penWidth, highlighterWidth, shapeWidth, fontSize;
  final ShapeKind shape;
}

/// The annotation layer over one page (DK-0312): draws [editor]'s
/// annotations and turns pointers into edits for the current tool. Lay it
/// exactly over the rendered page; [pageSize] is the page in points.
///
/// - Pen / Highlighter: a stroke becomes an ink annotation.
/// - Shapes: a drag draws [EditStyle.shape].
/// - Text / Note: a tap places a text box or a note (their sheets edit the
///   text) and selects it.
/// - Eraser: removes the ink it touches.
/// - Pan: a tap selects (or clears); dragging the selection moves it; its
///   corner handles resize it.
///
/// Palm rejection: once a stylus has drawn, touches no longer draw (they
/// still select and scroll), as on iPad with Apple Pencil.
class AnnotationOverlay extends StatefulWidget {
  const AnnotationOverlay({
    super.key,
    required this.editor,
    required this.page,
    required this.pageSize,
    this.style = const EditStyle(),
    this.onPlaced,
    this.onColour,
    this.onNote,
  });

  final AnnotationEditor editor;
  final int page;
  final Size pageSize;
  final EditStyle style;

  /// A text box or note was placed: open its sheet.
  final ValueChanged<AnnotRef>? onPlaced;

  /// The mini bar's Colour and Add note (DK-0322): open their sheets.
  /// Duplicate and Delete act here (both undoable).
  final ValueChanged<AnnotRef>? onColour, onNote;

  @override
  State<AnnotationOverlay> createState() => _AnnotationOverlayState();
}

enum _Drag { none, draw, move, resize }

class _AnnotationOverlayState extends State<AnnotationOverlay> {
  int? _pointer;
  var _drag = _Drag.none;
  final _stroke = <PagePoint>[];
  PagePoint? _start, _last;
  int _corner = 0; // 0 tl, 1 tr, 2 br, 3 bl
  Box? _resizeFrom;

  AnnotationEditor get _e => widget.editor;

  /// Points per logical pixel, for the size the overlay got.
  double _scale(Size size) => widget.pageSize.width / size.width;

  PagePoint _toPage(Offset o, Size size) {
    final s = _scale(size);
    return (x: o.dx * s, y: widget.pageSize.height - o.dy * s);
  }

  Rect _toWidget(Box b, Size size) {
    final k = 1 / _scale(size);
    return Rect.fromLTRB(
      b.left * k,
      (widget.pageSize.height - b.top) * k,
      b.right * k,
      (widget.pageSize.height - b.bottom) * k,
    );
  }

  /// A finger's tolerance in points: 8 logical pixels.
  double _tolerance(Size size) => 8 * _scale(size);

  bool _draws(EditTool t) =>
      t == EditTool.pen || t == EditTool.highlighter || t == EditTool.shapes;

  void _down(PointerDownEvent ev, Size size) {
    if (_pointer != null) return;
    final stylus =
        ev.kind == PointerDeviceKind.stylus ||
        ev.kind == PointerDeviceKind.invertedStylus;
    final tool = _e.tool;
    if (_draws(tool) && stylus) _e.stylusSeen = true;
    if (_draws(tool) && _e.stylusSeen && !stylus) return; // a palm
    _pointer = ev.pointer;
    final at = _toPage(ev.localPosition, size);
    _start = _last = at;
    switch (tool) {
      case EditTool.pen || EditTool.highlighter || EditTool.shapes:
        _drag = _Drag.draw;
        _stroke
          ..clear()
          ..add(at);
      case EditTool.eraser:
        _drag = _Drag.draw;
        _erase(at, size);
      case EditTool.text || EditTool.note:
        _drag = _Drag.none;
      case EditTool.pan:
        final sel = _e.selectedAnnot;
        final corner = sel == null
            ? null
            : _cornerAt(sel.annot.bounds, at, size);
        if (corner != null) {
          _drag = _Drag.resize;
          _corner = corner;
          _resizeFrom = sel!.annot.bounds;
        } else if (sel != null && hits(sel.annot, at, _tolerance(size))) {
          _drag = _Drag.move;
        } else {
          _drag = _Drag.none;
        }
    }
    setState(() {});
  }

  void _move(PointerMoveEvent ev, Size size) {
    if (ev.pointer != _pointer) return;
    final at = _toPage(ev.localPosition, size);
    switch (_drag) {
      case _Drag.draw when _e.tool == EditTool.eraser:
        // Along the whole move, so a fast swipe can't jump over a thin line.
        final from = _last!;
        final step = _tolerance(size) / 2;
        final n = math.max(
          1,
          (math.sqrt(math.pow(at.x - from.x, 2) + math.pow(at.y - from.y, 2)) /
                  step)
              .ceil(),
        );
        for (var i = 1; i <= n; i++) {
          _erase((
            x: from.x + (at.x - from.x) * i / n,
            y: from.y + (at.y - from.y) * i / n,
          ), size);
        }
      case _Drag.draw:
        _stroke.add(at);
      case _Drag.move || _Drag.resize || _Drag.none:
        break;
    }
    _last = at;
    setState(() {});
  }

  void _up(PointerEvent ev, Size size) {
    if (ev.pointer != _pointer) return;
    _pointer = null;
    final start = _start!, end = _last!;
    final tap =
        math.sqrt(math.pow(end.x - start.x, 2) + math.pow(end.y - start.y, 2)) <
        _tolerance(size) / 2;
    final st = widget.style;
    final page = widget.page;
    switch (_e.tool) {
      case EditTool.pen || EditTool.highlighter:
        final pen = _e.tool == EditTool.pen;
        if (_stroke.isNotEmpty) {
          _e.add(
            page,
            InkAnnot(
              [List.of(_stroke)],
              width: pen ? st.penWidth : st.highlighterWidth,
              color: pen ? st.penColor : st.highlighterColor,
            ),
            select: false,
          );
        }
      case EditTool.shapes:
        if (!tap) {
          _e.add(
            page,
            ShapeAnnot(
              st.shape,
              _boxOf(start, end),
              width: st.shapeWidth,
              color: st.shapeColor,
            ),
          );
        }
      case EditTool.text:
        // A tap on a text box edits it rather than stacking a new one.
        final hit = _e.hitTest(page, start, tolerance: _tolerance(size));
        if (hit != null &&
            _e
                .annotsOn(page)
                .any((a) => a.id == hit && a.annot is FreeTextAnnot)) {
          _e.select((page: page, id: hit));
          widget.onPlaced?.call((page: page, id: hit));
          break;
        }
        final id = _e.add(
          page,
          FreeTextAnnot(
            (
              left: start.x,
              top: start.y,
              right: start.x + 160,
              bottom: start.y - st.fontSize * 1.6,
            ),
            '',
            fontSize: st.fontSize,
            color: st.textColor,
          ),
        );
        widget.onPlaced?.call((page: page, id: id));
      case EditTool.note:
        final id = _e.add(
          page,
          NoteAnnot(start, note: '', color: st.noteColor),
        );
        widget.onPlaced?.call((page: page, id: id));
      case EditTool.eraser:
        break;
      case EditTool.pan:
        final sel = _e.selected;
        if (_drag == _Drag.move && !tap && sel != null) {
          _e.move(sel, end.x - start.x, end.y - start.y);
        } else if (_drag == _Drag.resize && sel != null) {
          _e.resize(sel, _resized(_resizeFrom!, _corner, end));
        } else if (tap) {
          final id = _e.hitTest(page, end, tolerance: _tolerance(size));
          _e.select(id == null ? null : (page: page, id: id));
        }
    }
    _drag = _Drag.none;
    _stroke.clear();
    setState(() {});
  }

  void _erase(PagePoint at, Size size) {
    for (final a in _e.annotsOn(widget.page).reversed) {
      if (a.annot is InkAnnot && hits(a.annot, at, _tolerance(size))) {
        _e.delete((page: widget.page, id: a.id));
        return;
      }
    }
  }

  /// The handle under [at]: a 44 dp target around each corner.
  int? _cornerAt(Box b, PagePoint at, Size size) {
    final reach = 22 * _scale(size);
    final corners = [
      (b.left, b.top),
      (b.right, b.top),
      (b.right, b.bottom),
      (b.left, b.bottom),
    ];
    for (var i = 0; i < 4; i++) {
      if ((at.x - corners[i].$1).abs() <= reach &&
          (at.y - corners[i].$2).abs() <= reach) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final size = Size(
        c.maxWidth,
        c.maxWidth * widget.pageSize.height / widget.pageSize.width,
      );
      // Pan without a selection lets the viewer scroll and zoom.
      final passive =
          _e.tool == EditTool.pan && _e.selected == null && _pointer == null;
      final listener = Listener(
        behavior: passive
            ? HitTestBehavior.translucent
            : HitTestBehavior.opaque,
        onPointerDown: (e) => _down(e, size),
        onPointerMove: (e) => _move(e, size),
        onPointerUp: (e) => _up(e, size),
        onPointerCancel: (e) => _up(e, size),
        child: ListenableBuilder(
          listenable: _e,
          builder: (context, _) => CustomPaint(
            size: size,
            painter: AnnotationPainter(
              annots: [
                for (final a in _e.annotsOn(widget.page))
                  if (!(_drag == _Drag.move && _e.selected?.id == a.id))
                    a.annot,
                if (_drag == _Drag.move && _e.selectedAnnot != null)
                  translate(
                    _e.selectedAnnot!.annot,
                    _last!.x - _start!.x,
                    _last!.y - _start!.y,
                  ),
                if (_drag == _Drag.draw &&
                    _e.tool == EditTool.pen &&
                    _stroke.isNotEmpty)
                  InkAnnot(
                    [_stroke],
                    width: widget.style.penWidth,
                    color: widget.style.penColor,
                  ),
                if (_drag == _Drag.draw &&
                    _e.tool == EditTool.highlighter &&
                    _stroke.isNotEmpty)
                  InkAnnot(
                    [_stroke],
                    width: widget.style.highlighterWidth,
                    color: widget.style.highlighterColor,
                  ),
                if (_drag == _Drag.draw &&
                    _e.tool == EditTool.shapes &&
                    _last != null)
                  ShapeAnnot(
                    widget.style.shape,
                    _boxOf(_start!, _last!),
                    width: widget.style.shapeWidth,
                    color: widget.style.shapeColor,
                  ),
              ],
              selected: switch ((_drag, _e.selectedAnnot)) {
                (_Drag.move, final s?) => translate(
                  s.annot,
                  _last!.x - _start!.x,
                  _last!.y - _start!.y,
                ).bounds,
                (_Drag.resize, _?) => _resized(_resizeFrom!, _corner, _last!),
                (_, final s?) => s.annot.bounds,
                _ => null,
              },
              pageSize: widget.pageSize,
              ring: context.tokens.color.primary,
              handleFill: context.tokens.color.surface,
            ),
          ),
        ),
      );
      // The mini bar over the selection, while nothing is being dragged.
      return ListenableBuilder(
        listenable: _e,
        builder: (context, _) => Stack(
          clipBehavior: Clip.none,
          children: [
            listener,
            if (_e.selectedAnnot case final sel? when _pointer == null)
              DkAnnotBar.over(
                selection: _toWidget(sel.annot.bounds, size).inflate(4),
                color: Color(sel.annot.color),
                onAction: (a) {
                  final ref = _e.selected!;
                  switch (a) {
                    case DkAnnotAction.colour:
                      widget.onColour?.call(ref);
                    case DkAnnotAction.duplicate:
                      _e.duplicate(ref);
                    case DkAnnotAction.note:
                      widget.onNote?.call(ref);
                    case DkAnnotAction.delete:
                      _e.delete(ref);
                  }
                },
              ),
          ],
        ),
      );
    },
  );
}

Box _boxOf(PagePoint a, PagePoint b) => (
  left: math.min(a.x, b.x),
  top: math.max(a.y, b.y),
  right: math.max(a.x, b.x),
  bottom: math.min(a.y, b.y),
);

/// [b] with its [corner] dragged to [to] (never inside out: at least 8 pt).
Box _resized(Box b, int corner, PagePoint to) {
  var (l, t, r, bo) = (b.left, b.top, b.right, b.bottom);
  switch (corner) {
    case 0:
      (l, t) = (math.min(to.x, r - 8), math.max(to.y, bo + 8));
    case 1:
      (r, t) = (math.max(to.x, l + 8), math.max(to.y, bo + 8));
    case 2:
      (r, bo) = (math.max(to.x, l + 8), math.min(to.y, t - 8));
    default:
      (l, bo) = (math.min(to.x, r - 8), math.min(to.y, t - 8));
  }
  return (left: l, top: t, right: r, bottom: bo);
}

/// Paints annotations in page space over a page drawn at the painter's
/// size, plus the selection's frame and corner handles.
class AnnotationPainter extends CustomPainter {
  const AnnotationPainter({
    required this.annots,
    required this.pageSize,
    required this.ring,
    required this.handleFill,
    this.selected,
  });

  final List<PdfAnnot> annots;
  final Size pageSize;
  final Box? selected;

  /// The selection colour (`color.primary`) and the handles' fill
  /// (`color.surface`).
  final Color ring, handleFill;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / pageSize.width;
    Offset o(PagePoint p) => Offset(p.x * s, (pageSize.height - p.y) * s);
    Rect r(Box b) => Rect.fromLTRB(
      b.left * s,
      (pageSize.height - b.top) * s,
      b.right * s,
      (pageSize.height - b.bottom) * s,
    );
    for (final a in annots) {
      final color = Color(a.color);
      switch (a) {
        case InkAnnot(:final strokes, :final width):
          final paint = Paint()
            ..color = color
            ..strokeWidth = width * s
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;
          for (final st in strokes) {
            if (st.length == 1) {
              canvas.drawCircle(
                o(st[0]),
                width * s / 2,
                paint..style = PaintingStyle.fill,
              );
              paint.style = PaintingStyle.stroke;
              continue;
            }
            canvas.drawPath(
              Path()..addPolygon([for (final p in st) o(p)], false),
              paint,
            );
          }
        case MarkupAnnot(:final kind, :final quads):
          for (final (p1, p2, p3, p4) in quads) {
            switch (kind) {
              case MarkupKind.highlight:
                canvas.drawPath(
                  Path()..addPolygon([o(p1), o(p2), o(p4), o(p3)], true),
                  Paint()
                    ..color = color
                    ..blendMode = BlendMode.multiply,
                );
              case MarkupKind.underline || MarkupKind.squiggly:
                canvas.drawLine(
                  o(p3),
                  o(p4),
                  Paint()
                    ..color = color
                    ..strokeWidth = math.max(1, s),
                );
              case MarkupKind.strikeOut:
                final mid = (
                  Offset.lerp(o(p1), o(p3), 0.5)!,
                  Offset.lerp(o(p2), o(p4), 0.5)!,
                );
                canvas.drawLine(
                  mid.$1,
                  mid.$2,
                  Paint()
                    ..color = color
                    ..strokeWidth = math.max(1, s),
                );
            }
          }
        case ShapeAnnot(:final kind, :final rect, :final width, :final fill):
          final rr = r(rect);
          void draw(Paint p) => kind == ShapeKind.square
              ? canvas.drawRect(rr, p)
              : canvas.drawOval(rr, p);
          if (fill != null) draw(Paint()..color = Color(fill));
          draw(
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = width * s,
          );
        case FreeTextAnnot(:final rect, :final text, :final fontSize):
          final rr = r(rect);
          final builder =
              ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: fontSize * s))
                ..pushStyle(ui.TextStyle(color: color))
                ..addText(text);
          final para = builder.build()
            ..layout(ui.ParagraphConstraints(width: rr.width));
          canvas.drawParagraph(para, rr.topLeft);
        case NoteAnnot():
          final rr = r(a.bounds);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rr, Radius.circular(3 * s)),
            Paint()..color = color,
          );
          final lines = Paint()
            ..color = HSLColor.fromColor(color).withLightness(0.3).toColor()
            ..strokeWidth = math.max(1, 1.5 * s);
          for (final f in [0.35, 0.55, 0.75]) {
            canvas.drawLine(
              rr.topLeft + Offset(rr.width * 0.2, rr.height * f),
              rr.topLeft + Offset(rr.width * 0.8, rr.height * f),
              lines,
            );
          }
        case OtherAnnot():
          break;
      }
    }
    if (selected case final b?) {
      // The design's frame: 1 dp dashed primary, 4 outside the annotation,
      // and 9 dp square handles (surface, 2 dp primary) on its corners.
      final rr = r(b).inflate(4);
      final dash = Paint()
        ..color = ring
        ..strokeWidth = 1;
      for (final (a, z) in [
        (rr.topLeft, rr.topRight),
        (rr.topRight, rr.bottomRight),
        (rr.bottomRight, rr.bottomLeft),
        (rr.bottomLeft, rr.topLeft),
      ]) {
        final len = (z - a).distance;
        for (var d = 0.0; d < len; d += 8) {
          canvas.drawLine(
            Offset.lerp(a, z, d / len)!,
            Offset.lerp(a, z, math.min(d + 4, len) / len)!,
            dash,
          );
        }
      }
      for (final c in [
        rr.topLeft,
        rr.topRight,
        rr.bottomRight,
        rr.bottomLeft,
      ]) {
        final h = Rect.fromCenter(center: c, width: 9, height: 9);
        canvas.drawRect(h, Paint()..color = handleFill);
        canvas.drawRect(
          h,
          Paint()
            ..color = ring
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(AnnotationPainter old) => true; // ponytail: cheap; compare lists if it shows in a profile
}
