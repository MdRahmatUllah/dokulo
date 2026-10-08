import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_button.dart';
import 'dk_magnifier.dart';

/// Cropping a page (UI spec §11.5, §19.3; DK-0156): the uncropped [image]
/// with everything outside [quad] darkened (black at 50 %), the quad's 2 dp
/// `color.quadStroke` border, 4 corner handles (24 circles, white with a
/// 2 dp primary ring, a 44 target) and 4 edge handles (24 × 8 pills), and
/// Auto · Full page · Reset under the image (those given a callback).
///
/// [quad] is top-left, top-right, bottom-right, bottom-left, as fractions of
/// the image (0–1). A corner follows the finger, snaps to a detected corner
/// ([snapTo]) within 16 dp, and stays exactly where it was when the finger
/// lifts. The quad stays convex. [rectangle]: no perspective (Crop pages),
/// so a corner moves two sides and an edge moves one.
///
/// While a corner is dragged its handle hides and DkMagnifier shows the
/// page under it. The handles are for fingers; the three buttons are the
/// way without dragging (WCAG 2.5.7), and screen readers get those.
class DkCropOverlay extends StatefulWidget {
  const DkCropOverlay({
    super.key,
    required this.image,
    required this.aspectRatio,
    required this.quad,
    required this.onChanged,
    this.rectangle = false,
    this.snapTo,
    this.onAuto,
    this.onFullPage,
    this.onReset,
  }) : assert(quad.length == 4);

  final Widget image;

  /// The image's width : height.
  final double aspectRatio;
  final List<Offset> quad;
  final ValueChanged<List<Offset>> onChanged;
  final bool rectangle;

  /// The detected document's corners (fractions), to snap to.
  final List<Offset>? snapTo;
  final VoidCallback? onAuto, onFullPage, onReset;

  /// Snap distance to a detected corner, and the smallest side.
  static const snap = 16.0, minSide = 32.0;

  @override
  State<DkCropOverlay> createState() => _DkCropOverlayState();
}

class _DkCropOverlayState extends State<DkCropOverlay> {
  /// The corner being dragged (0–3), or an edge (4–7: top, right, bottom,
  /// left), and the quad and finger movement since the drag began.
  int? _dragging;
  List<Offset>? _start;
  Offset _moved = Offset.zero;
  Size _size = Size.zero;

  Offset _px(Offset f) => Offset(f.dx * _size.width, f.dy * _size.height);
  Offset _frac(Offset p) => Offset(
    (p.dx / _size.width).clamp(0.0, 1.0),
    (p.dy / _size.height).clamp(0.0, 1.0),
  );

  void _begin(int handle) {
    setState(() => _dragging = handle);
    _start = [...widget.quad];
    _moved = Offset.zero;
  }

  void _end() => setState(() => _dragging = null);

  void _update(DragUpdateDetails d) {
    _moved += d.delta;
    final start = [for (final q in _start!) _px(q)];
    final h = _dragging!;
    var next = [...start];
    if (h < 4) {
      var p = start[h] + _moved;
      for (final target in widget.snapTo ?? const <Offset>[]) {
        final t = _px(target);
        if ((t - p).distance <= DkCropOverlay.snap) p = t;
      }
      if (widget.rectangle) {
        // A corner moves its two sides.
        final (x, y) = (p.dx, p.dy);
        final left = h == 0 || h == 3, top = h < 2;
        next = [
          for (final (i, q) in start.indexed)
            Offset(
              (i == 0 || i == 3) == left ? x : q.dx,
              (i < 2) == top ? y : q.dy,
            ),
        ];
      } else {
        next[h] = p;
      }
    } else {
      // An edge: its two corners. Rectangle mode moves only across it.
      final e = h - 4, a = e, b = (e + 1) % 4;
      final across = widget.rectangle
          ? (e.isEven ? Offset(0, _moved.dy) : Offset(_moved.dx, 0))
          : _moved;
      next[a] = start[a] + across;
      next[b] = start[b] + across;
    }
    final bounded = [for (final q in next) _frac(q)];
    if (_valid([for (final q in bounded) _px(q)])) widget.onChanged(bounded);
  }

  /// Convex, in order, and no side shorter than [DkCropOverlay.minSide].
  static bool _valid(List<Offset> q) {
    double cross(Offset o, Offset a, Offset b) =>
        (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
    final turns = [
      for (var i = 0; i < 4; i++) cross(q[i], q[(i + 1) % 4], q[(i + 2) % 4]),
    ];
    final convex = turns.every((c) => c > 0) || turns.every((c) => c < 0);
    final sides = [
      for (var i = 0; i < 4; i++) (q[(i + 1) % 4] - q[i]).distance,
    ];
    return convex && sides.every((s) => s >= DkCropOverlay.minSide);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    Widget button(String label, VoidCallback? onPressed) => DkButton(
      label: label,
      onPressed: onPressed,
      variant: DkButtonVariant.secondary,
      size: DkButtonSize.compact,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: LayoutBuilder(
            builder: (context, box) {
              _size = box.biggest;
              final q = [for (final f in widget.quad) _px(f)];
              final dragged = _dragging;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: widget.image),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _QuadPainter(
                        q,
                        // Black at 50 %: the camera chrome's black.
                        shade: t.color.cameraChrome.withValues(alpha: 0.5),
                        stroke: t.color.quadStroke,
                      ),
                    ),
                  ),
                  for (var i = 0; i < 4; i++)
                    _Handle(
                      at: q[i],
                      hidden: dragged == i,
                      shape: const Size(24, 24),
                      onStart: () => _begin(i),
                      onUpdate: _update,
                      onEnd: _end,
                    ),
                  for (var e = 0; e < 4; e++)
                    _Handle(
                      at: Offset.lerp(q[e], q[(e + 1) % 4], 0.5)!,
                      hidden: false,
                      shape: e.isEven ? const Size(24, 8) : const Size(8, 24),
                      onStart: () => _begin(4 + e),
                      onUpdate: _update,
                      onEnd: _end,
                    ),
                  if (dragged != null && dragged < 4)
                    DkMagnifier(finger: q[dragged]),
                ],
              );
            },
          ),
        ),
        SizedBox(height: t.space.m),
        Wrap(
          spacing: t.space.s,
          runSpacing: t.space.s,
          alignment: WrapAlignment.center,
          children: [
            // Only the ones the screen offers (Crop pages has no Full page).
            if (widget.onAuto != null) button(l10n.crop_auto, widget.onAuto),
            if (widget.onFullPage != null)
              button(l10n.crop_full_page, widget.onFullPage),
            if (widget.onReset != null) button(l10n.crop_reset, widget.onReset),
          ],
        ),
      ],
    );
  }
}

/// A 44 target centred on [at], drawing a white shape with a 2 dp primary
/// ring: a 24 circle (corners) or a 24 × 8 pill (edges).
class _Handle extends StatelessWidget {
  const _Handle({
    required this.at,
    required this.hidden,
    required this.shape,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final Offset at;
  final bool hidden;
  final Size shape;
  final VoidCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final VoidCallback onEnd;

  static const hit = 44.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Positioned(
      left: at.dx - hit / 2,
      top: at.dy - hit / 2,
      width: hit,
      height: hit,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => onStart(),
          onPanUpdate: onUpdate,
          onPanEnd: (_) => onEnd(),
          onPanCancel: onEnd,
          child: hidden
              ? null
              : Center(
                  child: Container(
                    width: shape.width,
                    height: shape.height,
                    decoration: BoxDecoration(
                      color: t.color.onCamera,
                      border: Border.all(color: t.color.primary, width: 2),
                      borderRadius: BorderRadius.circular(
                        shape.shortestSide / 2,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _QuadPainter extends CustomPainter {
  _QuadPainter(this.quad, {required this.shade, required this.stroke});

  final List<Offset> quad;
  final Color shade, stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()..addPolygon(quad, true);
    canvas
      ..drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(Offset.zero & size),
          outline,
        ),
        Paint()..color = shade,
      )
      ..drawPath(
        outline,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  @override
  bool shouldRepaint(_QuadPainter old) =>
      old.shade != shade || old.stroke != stroke || !_same(old.quad, quad);

  static bool _same(List<Offset> a, List<Offset> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((s) => s);
}
