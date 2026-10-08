import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/dk_tokens.dart';
import '../theme/haptics.dart';
import 'dk_icon.dart';
import 'dk_tappable.dart';

/// A filter chip (several can be on) or a choice chip (one of a group).
enum DkChipKind { filter, choice }

/// A chip (DK-0104; UI spec §11.3): 32 dp, 12 padding, a pill.
/// - Filter: off has a 1 dp `color.outlineStrong` border; on fills
///   `color.primaryContainer` with a 16 dp check and `onPrimaryContainer`
///   text.
/// - Choice: on fills `color.primary` with `onPrimary` text.
///
/// Selecting plays the selection haptic. 48 dp to touch; pressed shows the
/// overlay; the keyboard reaches it (the 2 dp focus ring, Enter or Space).
/// In a choice group the selected chip stays on: tapping it does nothing.
class DkChip extends ConsumerWidget {
  const DkChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.kind = DkChipKind.filter,
    this.showPressed = false,
    this.showFocused = false,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final DkChipKind kind;

  /// Draw these states without a finger or keyboard: catalogue and goldens.
  final bool showPressed, showFocused;

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
    // A choice group keeps one chip on: tapping the selected one does nothing.
    final enabled = onSelected != null && !(selected && !filter);
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
      onTap: enabled ? tap : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Opacity(
            opacity: onSelected == null ? t.state.disabledOpacity : 1,
            child: DkTappable(
              onTap: enabled ? tap : null,
              radius: t.radius.pill,
              showPressed: showPressed,
              showFocused: showFocused,
              builder: (context, pressed) => Container(
                constraints: const BoxConstraints(minHeight: 32),
                padding: EdgeInsets.symmetric(horizontal: t.space.m),
                decoration: BoxDecoration(
                  color: pressed
                      ? Color.alphaBlend(t.state.pressed, fill ?? c.surface)
                      : fill,
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
