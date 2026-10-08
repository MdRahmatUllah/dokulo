import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';

/// A placeholder while content loads (UI spec §11.7; DK-0198): blocks in
/// `color.surfaceSunken`, `radius.xs`, pulsing gently (opacity 1 → 0.55 and
/// back in 1.2 s); still with Reduce Motion. Screen readers hear "Loading"
/// once for the whole skeleton.
///
/// One DkSkeleton per loading area: its label is read once, so a screen
/// wraps the whole area, not each row. The presets are the app's loading
/// shapes: [DkSkeleton.fileRows] (F1: six rows), [DkSkeleton.gridCard],
/// [DkSkeleton.page] and [DkSkeleton.modelCard] (M2). [DkSkeleton.new]
/// wraps any layout of [DkSkeletonBlock]s and the shapes
/// ([DkSkeletonFileRow], [DkSkeletonGridCard], [DkSkeletonModelCard]), e.g.
/// a grid of cards.
class DkSkeleton extends StatefulWidget {
  const DkSkeleton({super.key, required this.child});

  /// F1 while files load: [count] file rows (six), read as one "Loading".
  DkSkeleton.fileRows({super.key, int count = 6})
    : child = Column(
        children: [for (var i = 0; i < count; i++) const DkSkeletonFileRow()],
      );

  /// A file or folder card in the grid: the 3 : 4 thumbnail and two lines.
  const DkSkeleton.gridCard({super.key}) : child = const DkSkeletonGridCard();

  /// A page in the viewer or a grid: a 3 : 4 block.
  const DkSkeleton.page({super.key})
    : child = const AspectRatio(aspectRatio: 3 / 4, child: DkSkeletonBlock());

  /// An AI model card: a 40 icon, the name, the size, the button.
  const DkSkeleton.modelCard({super.key}) : child = const DkSkeletonModelCard();

  final Widget child;

  @override
  State<DkSkeleton> createState() => _DkSkeletonState();
}

class _DkSkeletonState extends State<DkSkeleton>
    with SingleTickerProviderStateMixin {
  /// Half the 1.2 s cycle: down, then back up.
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).common_loading,
    child: ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween(
          begin: 1.0,
          end: 0.55,
        ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
        child: widget.child,
      ),
    ),
  );
}

/// One grey block of a [DkSkeleton].
class DkSkeletonBlock extends StatelessWidget {
  const DkSkeletonBlock({
    super.key,
    this.width,
    this.height,
    this.circle = false,
  });

  final double? width, height;

  /// A round block (an avatar or a tool icon).
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: t.color.surfaceSunken,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(t.radius.xs),
      ),
    );
  }
}

/// Two text lines: [first] and [second] as fractions of the width.
class _Lines extends StatelessWidget {
  const _Lines({this.first = 0.7, this.second = 0.45});
  final double first, second;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FractionallySizedBox(
          widthFactor: first,
          child: const DkSkeletonBlock(height: 14),
        ),
        SizedBox(height: t.space.s),
        FractionallySizedBox(
          widthFactor: second,
          child: const DkSkeletonBlock(height: 10),
        ),
      ],
    );
  }
}

/// A file row's shape: a 40 × 52 thumbnail, the name and the meta line.
class DkSkeletonFileRow extends StatelessWidget {
  const DkSkeletonFileRow({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.space.l, vertical: t.space.s),
      child: Row(
        children: [
          const DkSkeletonBlock(width: 40, height: 52),
          SizedBox(width: t.space.m),
          const Expanded(child: _Lines()),
        ],
      ),
    );
  }
}

/// A grid card's shape: the 3 : 4 thumbnail and two lines.
class DkSkeletonGridCard extends StatelessWidget {
  const DkSkeletonGridCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const AspectRatio(aspectRatio: 3 / 4, child: DkSkeletonBlock()),
        SizedBox(height: t.space.s),
        const _Lines(first: 0.85, second: 0.5),
      ],
    );
  }
}

/// An AI model card's shape: a 40 icon, the name, the size, the button.
class DkSkeletonModelCard extends StatelessWidget {
  const DkSkeletonModelCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.all(t.space.l),
      child: Row(
        children: [
          const DkSkeletonBlock(width: 40, height: 40, circle: true),
          SizedBox(width: t.space.m),
          const Expanded(child: _Lines(first: 0.6, second: 0.35)),
          SizedBox(width: t.space.m),
          const DkSkeletonBlock(width: 88, height: 36),
        ],
      ),
    );
  }
}
