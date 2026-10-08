import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'dk_ring.dart';

/// A box on a page that moves, resizes by its corners and can be deleted:
/// the frame of DkRedactionBox and DkSignatureStamp (UI spec §11.5). A
/// [Positioned]: put it in the page's [Stack], with [rect] in its coordinates.
/// Flutter hit-tests only inside that Stack, so the screen keeps a box
/// [margin] in from the page's edges (30 at the top, for the ×), or the
/// handles there stop taking touches (the crop overlay's trap).
///
/// Selected, it shows square corner handles (9 dp, `color.surface` with a
/// 2 dp primary border, a 44 dp target each) and, with [onDelete], the delete
/// × (a 20 circle in the inverse colours) just above the top-right corner,
/// where it takes that corner's place: the design export draws it over that
/// handle, so resizing works from the other three.
class DkBoxFrame extends StatefulWidget {
  const DkBoxFrame({
    super.key,
    required this.rect,
    required this.child,
    this.selected = false,
    this.onChanged,
    this.onTap,
    this.onDelete,
    this.deleteLabel,
    this.semanticsLabel,
    this.keepAspect = false,
    this.minSize = const Size(24, 12),
  });

  final Rect rect;
  final Widget child;
  final bool selected;

  /// The box moved or was resized; null: it can't be changed.
  final ValueChanged<Rect>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  /// The × button's screen-reader label ("Remove signature").
  final String? deleteLabel;
  final String? semanticsLabel;

  /// Resizing keeps the width : height (a signature).
  final bool keepAspect;
  final Size minSize;

  /// Half a 44 dp target: room around the box for the handles and the ×.
  static const margin = 22.0;
  static const _handle = 9.0, _delete = 20.0;

  @override
  State<DkBoxFrame> createState() => _DkBoxFrameState();
}

class _DkBoxFrameState extends State<DkBoxFrame> {
  bool _focused = false;

  // The rect at the start of a drag, and where the finger has gone since.
  Rect? _start;
  Offset _moved = Offset.zero;

  void _begin(DragStartDetails _) {
    _start = widget.rect;
    _moved = Offset.zero;
  }

  void _move(DragUpdateDetails d) {
    _moved += d.delta;
    widget.onChanged!(_start!.shift(_moved));
  }

  /// Drags [corner] (0 top-left, 1 top-right, 2 bottom-right, 3 bottom-left);
  /// the opposite corner stays.
  void _resize(int corner, DragUpdateDetails d) {
    _moved += d.delta;
    final r = _start!;
    final min = widget.minSize;
    final fixed = [r.bottomRight, r.bottomLeft, r.topLeft, r.topRight][corner];
    final dragged =
        [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft][corner] + _moved;
    var w = math.max((dragged.dx - fixed.dx).abs(), min.width);
    var h = math.max((dragged.dy - fixed.dy).abs(), min.height);
    if (widget.keepAspect) {
      final aspect = r.width / r.height;
      // Follow the larger change, keep the shape.
      if (w / aspect > h) {
        h = w / aspect;
      } else {
        w = h * aspect;
      }
    }
    final left = corner == 0 || corner == 3 ? fixed.dx - w : fixed.dx;
    final top = corner < 2 ? fixed.dy - h : fixed.dy;
    widget.onChanged!(Rect.fromLTWH(left, top, w, h));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const m = DkBoxFrame.margin;
    final r = widget.rect;
    // The × sits 8 above the corner's target: the frame grows by that at
    // the top, so all of the ×'s target is inside it.
    final lift = t.space.s;
    final editable = widget.selected && widget.onChanged != null;
    final deletable = widget.selected && widget.onDelete != null;
    final corners = [
      Offset.zero,
      Offset(r.width, 0),
      Offset(r.width, r.height),
      Offset(0, r.height),
    ];

    Widget handle(int i) => Positioned(
      left: corners[i].dx,
      top: corners[i].dy + lift,
      width: 2 * m,
      height: 2 * m,
      // Handles are for fingers; screen readers move boxes in the list.
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _begin,
          onPanUpdate: (d) => _resize(i, d),
          child: Center(
            child: Container(
              width: DkBoxFrame._handle + 4,
              height: DkBoxFrame._handle + 4,
              decoration: BoxDecoration(
                color: t.color.surface,
                border: Border.fromBorderSide(t.selectionRing),
              ),
            ),
          ),
        ),
      ),
    );

    return Positioned.fromRect(
      rect: Rect.fromLTRB(
        r.left - m,
        r.top - m - lift,
        r.right + m,
        r.bottom + m,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: m,
            top: m + lift,
            width: r.width,
            height: r.height,
            child: Semantics(
              container: true,
              label: widget.semanticsLabel,
              selected: widget.selected,
              button: widget.onTap != null,
              child: DkRing(
                side: _focused ? t.focusRing : null,
                radius: 0,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: widget.onTap,
                    onFocusChange: (v) => setState(() => _focused = v),
                    overlayColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    splashFactory: NoSplash.splashFactory,
                    child: GestureDetector(
                      onPanStart: editable ? _begin : null,
                      onPanUpdate: editable ? _move : null,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (editable)
            for (final i in [0, if (!deletable) 1, 2, 3]) handle(i),
          if (deletable)
            Positioned(
              // Centred 8 above the top-right corner, as in the export.
              left: r.width,
              top: 0,
              width: 2 * m,
              height: 2 * m,
              child: Semantics(
                button: true,
                label: widget.deleteLabel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onDelete,
                  child: Center(
                    child: Container(
                      width: DkBoxFrame._delete,
                      height: DkBoxFrame._delete,
                      decoration: BoxDecoration(
                        color: t.color.inverseSurface,
                        shape: BoxShape.circle,
                      ),
                      child: DkIcon(
                        DkIcons.close,
                        size: DkIconSize.s,
                        color: t.color.onInverseSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A 1 dp dashed rectangle, rounded by [radius] (CSS `border: 1px dashed`:
/// 3 on, 3 off).
class DkDashedBorder extends CustomPainter {
  const DkDashedBorder(this.color, {this.radius = BorderRadius.zero});
  final Color color;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final outline = Path()
      ..addRRect(radius.toRRect(Offset.zero & size).deflate(0.5));
    for (final metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 6) {
        canvas.drawPath(metric.extractPath(d, d + 3), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DkDashedBorder old) =>
      old.color != color || old.radius != radius;
}
