import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/dk_tokens.dart';
import '../theme/haptics.dart';
import 'dk_icon.dart';

/// A filter chip (several can be on) or a choice chip (one of a group).
enum DkChipKind { filter, choice }

/// A chip (DK-0104; UI spec §11.3): 32 dp, 12 padding, a pill.
/// - Filter: off has a 1 dp `color.outlineStrong` border; on fills
///   `color.primaryContainer` with a 16 dp check and `onPrimaryContainer`
///   text.
/// - Choice: on fills `color.primary` with `onPrimary` text.
///
/// Selecting plays the selection haptic. 48 dp to touch.
class DkChip extends ConsumerWidget {
  const DkChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.kind = DkChipKind.filter,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final DkChipKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final c = t.color;
    final filter = kind == DkChipKind.filter;
    final (fill, ink) = !selected
        ? (null, c.textPrimary)
        : filter
        ? (c.primaryContainer, c.onPrimaryContainer)
        : (c.primary, c.onPrimary);
    void tap() {
      if (!selected) ref.read(hapticsProvider).selected();
      onSelected!(!selected);
    }

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: filter ? null : true,
      enabled: onSelected != null,
      label: label,
      excludeSemantics: true,
      onTap: onSelected == null ? null : tap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSelected == null ? null : tap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Opacity(
              opacity: onSelected == null ? t.state.disabledOpacity : 1,
              child: Container(
                constraints: const BoxConstraints(minHeight: 32),
                padding: EdgeInsets.symmetric(horizontal: t.space.m),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(t.radius.pill),
                  border: fill == null
                      ? Border.all(color: c.outlineStrong)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: t.space.xs,
                  children: [
                    if (filter && selected)
                      DkIcon(DkIcons.check, size: DkIconSize.s, color: ink),
                    Flexible(
                      child: Text(
                        label,
                        style: t.text.labelL.copyWith(color: ink),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
