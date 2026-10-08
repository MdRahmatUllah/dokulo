import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';
import 'dk_count_badge.dart';
import 'dk_tappable.dart';

/// A checkbox row (DK-0144; UI spec §11.4): a 24 dp checkbox, the [label] in
/// `type.bodyL` and an optional [count] badge at the end ("3"). The whole
/// row toggles, by finger or keyboard (focus ring, pressed overlay).
class DkCheckboxRow extends StatelessWidget {
  const DkCheckboxRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.count,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final enabled = onChanged != null;
    return MergeSemantics(
      child: DkTappable(
        onTap: enabled ? () => onChanged!(!value) : null,
        radius: t.radius.s,
        builder: (context, pressed) => Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: pressed ? t.state.pressed : null,
            borderRadius: BorderRadius.circular(t.radius.s),
          ),
          // Dimmed once, here: the checkbox keeps its enabled colours.
          child: Opacity(
            opacity: enabled ? 1 : t.state.disabledOpacity,
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 40,
                  // The row takes the focus and the taps.
                  child: ExcludeFocus(
                    child: Transform.scale(
                      scale: 24 / 18, // Material draws 18 dp; the spec says 24.
                      child: Checkbox(
                        value: value,
                        onChanged: enabled
                            ? (v) => onChanged!(v ?? false)
                            : null,
                        fillColor: WidgetStateProperty.resolveWith(
                          (s) => s.contains(WidgetState.selected)
                              ? c.primary
                              : Colors.transparent,
                        ),
                        checkColor: c.onPrimary,
                        side: WidgetStateBorderSide.resolveWith(
                          (s) => s.contains(WidgetState.selected)
                              ? BorderSide.none
                              : BorderSide(color: c.outlineStrong, width: 2),
                        ),
                        overlayColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: t.space.s),
                Expanded(child: Text(label, style: t.text.bodyL)),
                // Primary when checked, muted when not (the export's `.cb`).
                if (count != null) DkCountBadge(count!, muted: !value),
                SizedBox(width: t.space.s),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
