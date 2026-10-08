import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/dk_tokens.dart';

/// Success tick (UI spec §9; DK-0041), at the top of a result card: the
/// circle draws (200 ms), then the check (`motion.fast`), in `color.success`.
/// It plays once, when it is first shown. With Reduce Motion it fades in
/// whole (120 ms). Decorative: the card's text says what succeeded. The
/// medium haptic (`saved()`) is the caller's, when the file is saved.
class DkSuccessTick extends StatefulWidget {
  const DkSuccessTick({super.key, this.size = 32});

  final double size;

  @override
  State<DkSuccessTick> createState() => _DkSuccessTickState();
}

class _DkSuccessTickState extends State<DkSuccessTick>
    with SingleTickerProviderStateMixin {
  late final _draw = AnimationController(vsync: this);
  var _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draw.status != AnimationStatus.dismissed) return;
    final motion = context.tokens.motion;
    _reduce = context.reduceMotion;
    _draw
      ..duration = _reduce ? motion.reduced : motion.tickCircle + motion.fast
      ..forward();
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.tokens.motion;
    final split =
        motion.tickCircle.inMicroseconds /
        (motion.tickCircle + motion.fast).inMicroseconds;
    final circle = CurvedAnimation(
      parent: _draw,
      curve: Interval(0, split, curve: motion.fastCurve),
    );
    final check = CurvedAnimation(
      parent: _draw,
      curve: Interval(split, 1, curve: motion.fastCurve),
    );
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _draw,
        builder: (context, _) => Opacity(
          opacity: _reduce ? _draw.value : 1,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _TickPainter(
              color: context.tokens.color.success,
              circle: _reduce ? 1 : circle.value,
              check: _reduce ? 1 : check.value,
            ),
          ),
        ),
      ),
    );
  }
}

/// The export's tick (viewBox 36: circle r 16, check M11 18.5 l5 5 9-10,
/// stroke 3), drawn up to [circle] and [check] (0–1).
class _TickPainter extends CustomPainter {
  _TickPainter({
    required this.color,
    required this.circle,
    required this.check,
  });

  final Color color;
  final double circle, check;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 36);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (circle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(18, 18), radius: 16),
        -math.pi / 2,
        2 * math.pi * circle,
        false,
        pen,
      );
    }
    if (check > 0) {
      final tick = Path()
        ..moveTo(11, 18.5)
        ..relativeLineTo(5, 5)
        ..relativeLineTo(9, -10);
      final metric = tick.computeMetrics().single;
      canvas.drawPath(metric.extractPath(0, metric.length * check), pen);
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.circle != circle || old.check != check || old.color != color;
}

/// Success tick, the number (DK-0041): counts from [from] to [to] over
/// 400 ms once the tick has drawn ([delay]), shown through [format]
/// ("1.9 MB"). Screen readers read the final value only. With Reduce Motion
/// the final value fades in (120 ms).
class DkCountUp extends StatefulWidget {
  const DkCountUp({
    super.key,
    required this.from,
    required this.to,
    required this.format,
    this.style,
    this.delay,
  });

  final double from, to;
  final String Function(double value) format;
  final TextStyle? style;

  /// Defaults to the tick's drawing time, so the count starts as it ends.
  final Duration? delay;

  @override
  State<DkCountUp> createState() => _DkCountUpState();
}

class _DkCountUpState extends State<DkCountUp>
    with SingleTickerProviderStateMixin {
  late final _count = AnimationController(vsync: this);
  late Animation<double> _t;
  var _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_count.status != AnimationStatus.dismissed) return;
    final motion = context.tokens.motion;
    _reduce = context.reduceMotion;
    if (_reduce) {
      _count.duration = motion.reduced;
      _t = _count;
    } else {
      final wait = widget.delay ?? motion.tickCircle + motion.fast;
      final total = wait + motion.countUp;
      _count.duration = total;
      _t = CurvedAnimation(
        parent: _count,
        curve: Interval(
          wait.inMicroseconds / total.inMicroseconds,
          1,
          curve: motion.standardCurve,
        ),
      );
    }
    _count.forward();
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.format(widget.to),
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) => _reduce
            ? Opacity(
                opacity: _t.value,
                child: Text(widget.format(widget.to), style: widget.style),
              )
            : Text(
                widget.format(
                  widget.from + (widget.to - widget.from) * _t.value,
                ),
                style: widget.style,
              ),
      ),
    ),
  );
}
