import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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

/// How long a press lifts an item (§12.2), not the platform's 500 ms.
const dkLiftDelay = Duration(milliseconds: 300);

/// Keeps a scrollable moving while a dragging finger is within [edge] of
/// its leading or trailing side (§12.2). Feed it every drag update; stop it
/// when the drag ends.
class DkEdgeScroller {
  DkEdgeScroller(this.controller, {this.axis = Axis.vertical, this.onScroll});

  final ScrollController controller;
  final Axis axis;

  /// After every step: the finger stayed still but what's under it moved.
  final VoidCallback? onScroll;

  static const edge = 48.0;

  /// Pixels per frame.
  static const step = 6.0;

  Timer? _timer;

  bool get scrolling => _timer != null;

  /// [local] is the finger in the scrollable's own box, of [size].
  void update(Offset local, Size size) {
    final at = axis == Axis.vertical ? local.dy : local.dx;
    final length = axis == Axis.vertical ? size.height : size.width;
    final delta = at < edge
        ? -step
        : at > length - edge
        ? step
        : 0.0;
    if (delta == 0) return stop();
    _timer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!controller.hasClients) return;
      final p = controller.position;
      final next = (p.pixels + delta).clamp(
        p.minScrollExtent,
        p.maxScrollExtent,
      );
      if (next == p.pixels) return;
      controller.jumpTo(next);
      onScroll?.call();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

/// For a `ReorderableListView` (merge cards, workflow steps, the page tray)
/// with `buildDefaultDragHandles: false`: wrap each item so a 300 ms press
/// lifts it (§12.2) instead of the platform's 500 ms.
class DkReorderStartListener extends ReorderableDragStartListener {
  const DkReorderStartListener({
    super.key,
    required super.child,
    required super.index,
    super.enabled,
  });

  @override
  MultiDragGestureRecognizer createRecognizer() =>
      DelayedMultiDragGestureRecognizer(delay: dkLiftDelay, debugOwner: this);
}

/// A `ReorderableListView.proxyDecorator`: the lifted item grows to 1.04
/// with the floating shadow (DkLift), on a Material for its ink.
Widget dkReorderProxy(Widget child, int index, Animation<double> animation) =>
    Material(
      type: MaterialType.transparency,
      child: DkLift(lifted: true, child: child),
    );
