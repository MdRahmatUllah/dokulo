import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'dk_number_text.dart';
import 'dk_tappable.dart';

/// One level of a tool (Compress: Light, Recommended, Strong).
typedef DkLevelOption = ({String title, String estimate, String description});

/// The level cards (DK-0092; UI spec §11.2): a row of equal cards, stacked
/// below 360 dp width or at 160 % text and above. Each: 12 padding,
/// `radius.m`, a 1 dp `color.outline`; the title in `type.labelM` (one
/// line), the estimate in `type.titleM` with tabular figures ("≈ 1.9 MB"),
/// the description in `type.caption`. The selected card has a 2 dp
/// `color.primary` border, a 20 dp check circle top-right and
/// `primaryContainer` at 50 %. The check sits on the corner, off the title.
class DkLevelCards<T> extends StatelessWidget {
  const DkLevelCards({
    super.key,
    required this.levels,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, DkLevelOption)> levels;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return LayoutBuilder(
      builder: (context, box) {
        final stack =
            box.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(10) >= 16;
        final cards = [
          for (final (value, level) in levels)
            _LevelCard(
              level: level,
              selected: value == selected,
              onTap: () => onChanged(value),
            ),
        ];
        return stack
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: t.space.s,
                children: cards,
              )
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: t.space.s,
                  children: [for (final c in cards) Expanded(child: c)],
                ),
              );
      },
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final DkLevelOption level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: [level.title, level.estimate, level.description].join('\n'),
      excludeSemantics: true,
      onTap: onTap,
      // The check sits on the card's top-right corner, ringed in the
      // surface colour (the export's `.lv .ck`): the title keeps the width.
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: [
          DkTappable(
            onTap: onTap,
            radius: t.radius.m,
            builder: (context, pressed) => Container(
              padding: EdgeInsets.all(selected ? t.space.m - 1 : t.space.m),
              decoration: BoxDecoration(
                color: selected
                    ? c.primaryContainer.withValues(alpha: 0.5)
                    : (pressed ? t.state.pressed : null),
                borderRadius: BorderRadius.circular(t.radius.m),
                border: Border.all(
                  color: selected ? c.primary : c.outline,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: t.space.xxs,
                children: [
                  // labelM on one line, as every frame draws it: titleS
                  // can't fit "Recommended" in a third of a phone.
                  Text(
                    level.title,
                    style: t.text.labelM.copyWith(color: c.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  DkNumberText(
                    level.estimate,
                    style: t.text.titleM.copyWith(color: c.textPrimary),
                  ),
                  Text(
                    level.description,
                    style: t.text.caption.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          if (selected)
            Positioned(
              top: -9,
              right: -9,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: c.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.surface, width: 2),
                ),
                child: DkIcon(
                  DkIcons.check,
                  size: DkIconSize.s,
                  color: c.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
