import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../theme/dk_tokens.dart';

/// Scan capture, step 1 (UI spec §9; DK-0040): a white flash over the
/// viewfinder each time [captures] goes up, 80 ms from 95 % to clear. Off with
/// Reduce Motion, so nothing flashes then (WCAG 2.3.1).
class DkCaptureFlash extends StatefulWidget {
  const DkCaptureFlash({
    super.key,
    required this.captures,
    required this.child,
  });

  /// How many pages were captured; the flash plays when it goes up.
  final int captures;

  /// The viewfinder.
  final Widget child;

  @override
  State<DkCaptureFlash> createState() => _DkCaptureFlashState();
}

class _DkCaptureFlashState extends State<DkCaptureFlash>
    with SingleTickerProviderStateMixin {
  // preserve: Reduce Motion is handled here (the 120 ms cross-fade); the
  // default would also cut the duration to 5 % when the platform asks.
  late final _flash = AnimationController(
    vsync: this,
    value: 1,
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  void didUpdateWidget(DkCaptureFlash old) {
    super.didUpdateWidget(old);
    final motion = context.tokens.motion;
    if (widget.captures > old.captures &&
        motion.flashAllowed(reduce: context.reduceMotion)) {
      _flash
        ..duration = motion.captureFlash
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _flash,
            builder: (context, _) => _flash.isCompleted
                ? const SizedBox.shrink()
                : ColoredBox(
                    color: context.tokens.color.onCamera.withValues(
                      alpha: 0.95 * (1 - _flash.value),
                    ),
                  ),
          ),
        ),
      ),
    ],
  );
}

/// Scan capture, step 2 (DK-0040): the captured [page] shrinks and flies
/// from [from] (where it was in the viewfinder) into [to] (the tray's new
/// thumbnail), after the flash, in `motion.emphasis`. Both rects are global.
/// With Reduce Motion it fades out where it is (120 ms) instead.
///
/// Completes when it has landed: then add the page to the tray and bump the
/// counter, whose [DkPop] plays (the haptic is `captured()`, at the shutter).
Future<void> flyCapturedPage(
  BuildContext context, {
  required Widget page,
  required Rect from,
  required Rect to,
}) {
  final overlay = Overlay.of(context);
  final origin = (overlay.context.findRenderObject()! as RenderBox)
      .localToGlobal(Offset.zero);
  final landed = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Flight(
      page: page,
      from: from.shift(-origin),
      to: to.shift(-origin),
      onDone: () {
        entry
          ..remove()
          ..dispose();
        landed.complete();
      },
      // The overlay went away mid-flight (the scanner closed): don't leave
      // the caller waiting.
      onGone: () {
        if (!landed.isCompleted) landed.complete();
      },
    ),
  );
  overlay.insert(entry);
  return landed.future;
}

class _Flight extends StatefulWidget {
  const _Flight({
    required this.page,
    required this.from,
    required this.to,
    required this.onDone,
    required this.onGone,
  });

  final Widget page;
  final Rect from, to;
  final VoidCallback onDone, onGone;

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight> with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  late Animation<double> _t;
  late bool _reduce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_run.isAnimating || _run.isCompleted) return;
    final motion = context.tokens.motion;
    final fly = context.motion(DkMotionKind.emphasis);
    _reduce = fly.crossFade;
    // The flight waits for the flash; with Reduce Motion there is none.
    final wait = _reduce ? Duration.zero : motion.captureFlash;
    final total = wait + fly.duration;
    _run.duration = total;
    _t = CurvedAnimation(
      parent: _run,
      curve: Interval(
        wait.inMicroseconds / total.inMicroseconds,
        1,
        curve: fly.curve,
      ),
    );
    _run.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    if (!_run.isCompleted) widget.onGone();
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    builder: (context, child) {
      final t = _t.value;
      return Stack(
        children: [
          Positioned.fromRect(
            rect: _reduce ? widget.from : Rect.lerp(widget.from, widget.to, t)!,
            child: Opacity(
              opacity: _reduce ? 1 - t : 1 - 0.1 * t.clamp(0.0, 1.0),
              child: child,
            ),
          ),
        ],
      );
    },
    child: IgnorePointer(child: widget.page),
  );
}

/// Scan capture, step 3 (DK-0040): the counter badge pops (×1.35 and back,
/// `motion.emphasis`) when [value] changes. With Reduce Motion the new value
/// cross-fades in instead.
class DkPop extends StatefulWidget {
  const DkPop({super.key, required this.value, required this.child});

  /// What the child shows (the page count); a change plays the pop.
  final Object value;
  final Widget child;

  @override
  State<DkPop> createState() => _DkPopState();
}

class _DkPopState extends State<DkPop> with SingleTickerProviderStateMixin {
  late final _pop = AnimationController(
    vsync: this,
    value: 1,
    animationBehavior: AnimationBehavior.preserve,
  );
  Animation<double> _scale = const AlwaysStoppedAnimation(1);
  var _reduce = false;

  @override
  void didUpdateWidget(DkPop old) {
    super.didUpdateWidget(old);
    if (widget.value == old.value) return;
    final m = context.motion(DkMotionKind.emphasis);
    final peak = context.tokens.motion.popScale;
    _reduce = m.crossFade;
    _pop.duration = m.duration;
    _scale = _reduce
        ? const AlwaysStoppedAnimation(1)
        : TweenSequence([
            for (final (a, b) in [(1.0, peak), (peak, 1.0)])
              TweenSequenceItem(
                tween: Tween(
                  begin: a,
                  end: b,
                ).chain(CurveTween(curve: m.curve)),
                weight: 1,
              ),
          ]).animate(_pop);
    _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pop,
    builder: (context, child) => Opacity(
      opacity: _reduce ? _pop.value : 1,
      child: Transform.scale(scale: _scale.value, child: child),
    ),
    child: widget.child,
  );
}
