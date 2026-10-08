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
  late final _fade = AnimationController(vsync: this, value: 1);

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

/// Page drop (DK-0043): where a dragged page will land, between two
/// thumbnails: a 2 dp `color.primary` line with round end caps, pulsing
/// (1 → 35 % → 1, about 1 Hz) while it waits. Steady with Reduce Motion.
class DkInsertionLine extends StatefulWidget {
  const DkInsertionLine({
    super.key,
    required this.length,
    this.axis = Axis.vertical,
  });

  final double length;

  /// Vertical between thumbnails in a row; horizontal between rows.
  final Axis axis;

  @override
  State<DkInsertionLine> createState() => _DkInsertionLineState();
}

class _DkInsertionLineState extends State<DkInsertionLine>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, value: 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse
        ..duration = context.tokens.motion.insertionPulse ~/ 2
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const cap = 8.0; // the end caps (UI spec §11.5, DkPageGrid)
    final vertical = widget.axis == Axis.vertical;
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween(
          begin: 0.35,
          end: 1.0,
        ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
        child: CustomPaint(
          size: vertical ? Size(cap, widget.length) : Size(widget.length, cap),
          painter: _LinePainter(context.tokens.color.primary, widget.axis),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.color, this.axis);

  final Color color;
  final Axis axis;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    final r = (axis == Axis.vertical ? size.width : size.height) / 2;
    final (a, b) = axis == Axis.vertical
        ? (Offset(r, r), Offset(r, size.height - r))
        : (Offset(r, r), Offset(size.width - r, r));
    canvas
      ..drawLine(a, b, paint)
      ..drawCircle(a, r, paint)
      ..drawCircle(b, r, paint);
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.color != color || old.axis != axis;
}
