import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/dk_tokens.dart';

/// Sheet (UI spec §9; DK-0044): the route a sheet opens in. The sheet
/// slides up in `motion.standard` while the `color.scrim` fades in, in
/// `motion.fast`; a tap on the scrim or back closes it. With Reduce Motion
/// the sheet fades in where it ends (120 ms). DkSheet's `showDkSheet` pushes
/// it; the sheet's look, handle and detents are DkSheet's, this is the
/// motion.
///
/// ```dart
/// Navigator.of(context).push(DkSheetRoute.of(context, builder: (_) => sheet));
/// ```
class DkSheetRoute<T> extends PopupRoute<T> {
  DkSheetRoute({
    required this.builder,
    required this.motion,
    required this.scrimIn,
    required this.scrim,
    required this.dismissible,
    required this.label,
  });

  /// The route with the timings and colours of [context]'s theme, and its
  /// Reduce Motion setting.
  factory DkSheetRoute.of(
    BuildContext context, {
    required WidgetBuilder builder,
    bool dismissible = true,
  }) {
    final t = context.tokens;
    return DkSheetRoute(
      builder: builder,
      motion: context.motion(DkMotionKind.standard),
      scrimIn: t.motion.fast,
      scrim: t.color.scrim,
      dismissible: dismissible,
      label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    );
  }

  final WidgetBuilder builder;
  final DkMotionSpec motion;
  final Duration scrimIn;
  final Color scrim;
  final bool dismissible;
  final String label;

  @override
  Duration get transitionDuration => motion.duration;

  // Reduce Motion is the route's own 120 ms fade: keep its duration (the
  // default controller cuts it to 5 % when the platform disables animations).
  @override
  AnimationController createAnimationController() => AnimationController(
    duration: transitionDuration,
    reverseDuration: reverseTransitionDuration,
    debugLabel: debugLabel,
    vsync: navigator!,
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  Color get barrierColor => scrim;

  // The scrim is in after `motion.fast`, while the sheet is still moving.
  @override
  Curve get barrierCurve => motion.crossFade
      ? motion.curve
      : Interval(
          0,
          scrimIn.inMicroseconds / motion.duration.inMicroseconds,
          curve: Curves.linear,
        );

  @override
  bool get barrierDismissible => dismissible;

  @override
  String get barrierLabel => label;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Builder(builder: builder);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: motion.curve);
    return Align(
      alignment: Alignment.bottomCenter,
      child: motion.crossFade
          ? FadeTransition(opacity: curved, child: child)
          // By its own height: from just below the screen.
          : SlideTransition(
              position: Tween(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
    );
  }
}

/// Sheet detents (DK-0044): moves a `DraggableScrollableSheet` to [size]
/// (a fraction of the screen) in `motion.standard`. With Reduce Motion it
/// jumps there.
Future<void> animateDkSheetTo(
  BuildContext context,
  DraggableScrollableController sheet,
  double size,
) async {
  final m = context.motion(DkMotionKind.standard);
  if (m.crossFade) return sheet.jumpTo(size);
  await sheet.animateTo(size, duration: m.duration, curve: m.curve);
}

/// Mini job bar (DK-0045): "Keep working" shrinks the progress [sheet] into
/// the mini [bar] (and tapping the bar grows it back): the box morphs between
/// their heights in `motion.standard`, bottom-aligned, while the contents
/// cross-fade. The job keeps running either way. With Reduce Motion the box
/// takes its new size at once and the contents cross-fade (120 ms).
class DkJobMorph extends StatelessWidget {
  const DkJobMorph({
    super.key,
    required this.collapsed,
    required this.sheet,
    required this.bar,
  });

  final bool collapsed;
  final Widget sheet, bar;

  @override
  Widget build(BuildContext context) {
    final m = context.motion(DkMotionKind.standard);
    final contents = AnimatedSwitcher(
      duration: m.duration,
      switchInCurve: m.curve,
      switchOutCurve: m.curve,
      // The new contents size the box; the old fade out over them, clipped.
      layoutBuilder: (current, previous) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          for (final p in previous)
            Positioned(left: 0, right: 0, bottom: 0, child: p),
          ?current,
        ],
      ),
      child: KeyedSubtree(
        key: ValueKey(collapsed),
        child: collapsed ? bar : sheet,
      ),
    );
    return ClipRect(
      child: m.crossFade
          ? contents
          : AnimatedSize(
              duration: m.duration,
              curve: m.curve,
              alignment: Alignment.bottomCenter,
              child: contents,
            ),
    );
  }
}

/// Viewer open (DK-0046): the tapped file's thumbnail and the viewer's first
/// page share [tag] (`'file-$id'`), so the thumbnail expands into the page
/// while the viewer route ([dkViewerPage]) opens, in `motion.standard`. With
/// Reduce Motion nothing flies; the viewer cross-fades in (120 ms).
class DkHero extends StatelessWidget {
  const DkHero({super.key, required this.tag, required this.child});

  final Object tag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final m = context.motion(DkMotionKind.standard);
    return HeroMode(
      enabled: !m.crossFade,
      child: Hero(
        tag: tag,
        createRectTween: (a, b) => _CurvedRectTween(a, b, m.curve),
        child: child,
      ),
    );
  }
}

class _CurvedRectTween extends RectTween {
  _CurvedRectTween(Rect? begin, Rect? end, this.curve)
    : super(begin: begin, end: end);

  final Curve curve;

  @override
  Rect? lerp(double t) => super.lerp(curve.transform(t));
}

/// The viewer's route page (DK-0046): it fades in over `motion.standard`
/// while the [DkHero] flies (120 ms and no flight with Reduce Motion).
Page<void> dkViewerPage(
  BuildContext context, {
  required LocalKey key,
  required Widget child,
}) {
  final m = context.motion(DkMotionKind.standard);
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: m.duration,
    reverseTransitionDuration: m.duration,
    transitionsBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: m.curve),
      child: child,
    ),
  );
}
