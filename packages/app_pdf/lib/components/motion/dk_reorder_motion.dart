import 'package:flutter/widgets.dart';

import '../../theme/dk_tokens.dart';

/// Tile reorder (UI spec §9; DK-0042): a picked-up tile or page lifts (×1.04
/// and `elevation.floating`, `motion.standard`); dropped, it settles back the
/// same way. With Reduce Motion only the shadow cross-fades (120 ms), with no
/// scale. The haptics are the caller's: `selected()` on pick-up, `dropped()`
/// on landing.
class DkLift extends StatelessWidget {
  const DkLift({
    super.key,
    required this.lifted,
    required this.child,
    this.borderRadius,
  });

  final bool lifted;
  final Widget child;

  /// The tile's shape, so the shadow follows it.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final m = context.motion(DkMotionKind.standard);
    return AnimatedScale(
      scale: lifted && !m.crossFade ? t.motion.liftScale : 1,
      duration: m.duration,
      curve: m.curve,
      child: AnimatedContainer(
        duration: m.duration,
        curve: m.curve,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: lifted ? t.elevation.floating : const [],
        ),
        child: child,
      ),
    );
  }
}

/// Tile reorder and page drop (DK-0042, DK-0043): a tile placed at [rect] in
/// a `Stack`. When the layout moves it (a neighbour picked up, a page
/// dropped), it slides to its new place in `motion.standard`: the others
/// making room, and the dropped page settling. With Reduce Motion it appears
/// at the new place with a 120 ms fade. The tile under the finger is placed
/// with a plain `Positioned`: it follows the finger, not a timeline.
class DkSlot extends StatefulWidget {
  const DkSlot({super.key, required this.rect, required this.child});

  final Rect rect;
  final Widget child;

  @override
  State<DkSlot> createState() => _DkSlotState();
}

class _DkSlotState extends State<DkSlot> with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(
    vsync: this,
    value: 1,
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  void didUpdateWidget(DkSlot old) {
    super.didUpdateWidget(old);
    final m = context.motion(DkMotionKind.standard);
    if (m.crossFade && widget.rect != old.rect) {
      _fade
        ..duration = m.duration
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.motion(DkMotionKind.standard);
    return AnimatedPositioned.fromRect(
      rect: widget.rect,
      duration: m.crossFade ? Duration.zero : m.duration,
      curve: m.curve,
      child: FadeTransition(opacity: _fade, child: widget.child),
    );
  }
}

/// Page drop (DK-0043; UI spec §11.5): where a dragged page will land,
/// between two thumbnails: a 2 dp `color.primary` line with 8 dp end caps
/// across it (an I-beam). It doesn't move on its own; the drop settles with
/// [DkSlot].
class DkInsertionLine extends StatelessWidget {
  const DkInsertionLine({
    super.key,
    required this.length,
    this.axis = Axis.vertical,
  });

  final double length;

  /// Vertical between thumbnails in a row; horizontal between rows.
  final Axis axis;

  /// The end caps' width across the line.
  static const cap = 8.0;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: axis == Axis.vertical ? Size(cap, length) : Size(length, cap),
      painter: _LinePainter(context.tokens.color.primary, axis),
    ),
  );
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.color, this.axis);

  final Color color;
  final Axis axis;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const w = 2.0, cap = DkInsertionLine.cap;
    final vertical = axis == Axis.vertical;
    final length = vertical ? size.height : size.width;
    Rect r(double along, double across, double l, double a) => vertical
        ? Rect.fromLTWH(across, along, a, l)
        : Rect.fromLTWH(along, across, l, a);
    canvas
      ..drawRect(r(0, (cap - w) / 2, length, w), paint) // the line
      ..drawRect(r(0, 0, w, cap), paint) // the caps
      ..drawRect(r(length - w, 0, w, cap), paint);
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.color != color || old.axis != axis;
}
