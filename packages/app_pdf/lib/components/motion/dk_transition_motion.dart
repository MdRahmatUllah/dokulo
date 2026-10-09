import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
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

/// Dialogs (DkConfirmDialog; the tablet's DkSheet): the route a centred
/// dialog opens in. It fades in and grows from 96 % in `motion.standard`
/// (the export's `dk-dlg`), over the `color.scrim`; with Reduce Motion it
/// only fades, in 120 ms. A tap on the scrim, back or Esc closes it.
///
/// ```dart
/// Navigator.of(context).push(DkDialogRoute.of(context, builder: (_) => dialog));
/// ```
class DkDialogRoute<T> extends PopupRoute<T> {
  DkDialogRoute({
    required this.builder,
    required this.motion,
    required this.scrim,
    required this.label,
    this.dismissible = true,
  });

  /// The route with [context]'s theme timings, scrim and Reduce Motion.
  factory DkDialogRoute.of(
    BuildContext context, {
    required WidgetBuilder builder,
    bool dismissible = true,
  }) => DkDialogRoute(
    builder: builder,
    motion: context.motion(DkMotionKind.standard),
    scrim: context.tokens.color.scrim,
    label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    dismissible: dismissible,
  );

  final WidgetBuilder builder;
  final DkMotionSpec motion;
  final Color scrim;
  final String label;
  final bool dismissible;

  @override
  Duration get transitionDuration => motion.duration;

  // Keep the Reduce Motion fade's 120 ms (the default controller cuts it to
  // 5 % when the platform disables animations), as DkSheetRoute does.
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
    return FadeTransition(
      opacity: curved,
      child: motion.crossFade
          ? child
          : ScaleTransition(
              scale: Tween(begin: 0.96, end: 1.0).animate(curved),
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

/// Push (UI spec §13.4; DK-0237): iOS slides from the right (Cupertino's
/// own, with its back swipe); Android is a shared-axis X: the new page comes
/// in 30 dp from the right as it fades in, the old one leaves 30 dp to the
/// left as it fades out. With Reduce Motion both are a plain cross-fade.
/// The theme sets it for every pushed page ([dokuloTheme]).
class DkPageTransitionsBuilder extends PageTransitionsBuilder {
  const DkPageTransitionsBuilder();

  static const _shift = 30.0;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (context.reduceMotion) {
      return FadeTransition(opacity: animation, child: child);
    }
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return const CupertinoPageTransitionsBuilder().buildTransitions(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    final curve = context.tokens.motion.standardCurve;
    final enter = CurvedAnimation(parent: animation, curve: curve);
    final leave = CurvedAnimation(parent: secondaryAnimation, curve: curve);
    return AnimatedBuilder(
      animation: Listenable.merge([enter, leave]),
      child: child,
      builder: (context, child) => Opacity(
        opacity: enter.value * (1 - leave.value),
        child: Transform.translate(
          offset: Offset((1 - enter.value) * _shift - leave.value * _shift, 0),
          child: child,
        ),
      ),
    );
  }
}

/// Scanner open / close (UI spec §13.4; DK-0229): the page slides up from
/// the bottom in 220 ms and back down on close; with Reduce Motion it
/// cross-fades in 120 ms.
Page<void> dkSlideUpPage(
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
    transitionsBuilder: (context, animation, _, child) => m.crossFade
        ? FadeTransition(opacity: animation, child: child)
        : SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).chain(CurveTween(curve: m.curve)).animate(animation),
            child: child,
          ),
  );
}

/// Result after progress (UI spec §13.4; DK-0237): T3 cross-fades in over
/// the tool in 220 ms (120 ms with Reduce Motion).
Page<void> dkFadePage(
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
    transitionsBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// Tab switch (UI spec §13.4; DK-0229): the shell's tabs cross-fade in
/// 120 ms. Every tab's navigator stays alive (each keeps its stack and
/// scroll); only the current one takes touches, focus and semantics, and the
/// others are offstage, as in IndexedStack, once the fade has ended.
class DkFadingBranches extends StatefulWidget {
  const DkFadingBranches({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<DkFadingBranches> createState() => _DkFadingBranchesState();
}

class _DkFadingBranchesState extends State<DkFadingBranches>
    with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, value: 1);

  /// The tab fading out, while [_fade] runs.
  int? _previous;

  @override
  void didUpdateWidget(DkFadingBranches old) {
    super.didUpdateWidget(old);
    if (old.currentIndex == widget.currentIndex) return;
    _previous = old.currentIndex;
    _fade
      ..duration = context.tokens.motion.fast
      ..forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _previous = null);
      });
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      for (final (i, child) in widget.children.indexed) _branch(i, child),
    ],
  );

  Widget _branch(int i, Widget child) {
    final current = i == widget.currentIndex;
    final leaving = i == _previous;
    return Offstage(
      offstage: !current && !leaving,
      child: IgnorePointer(
        ignoring: !current,
        child: ExcludeFocus(
          excluding: !current,
          child: ExcludeSemantics(
            excluding: !current,
            child: TickerMode(
              enabled: current || leaving,
              child: current || leaving
                  ? FadeTransition(
                      opacity: current ? _fade : ReverseAnimation(_fade),
                      child: child,
                    )
                  : child,
            ),
          ),
        ),
      ),
    );
  }
}
