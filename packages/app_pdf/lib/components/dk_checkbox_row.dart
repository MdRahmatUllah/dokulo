import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';
import 'dk_number_text.dart';

/// A checkbox row (DK-0144; UI spec §11.4): a 24 dp checkbox, the [label] in
/// `type.bodyL` and an optional [count] badge at the end ("3"). The whole
/// row toggles.
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Opacity(
            opacity: enabled ? 1 : t.state.disabledOpacity,
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 40,
                  child: Checkbox(
                    value: value,
                    onChanged: enabled ? (v) => onChanged!(v ?? false) : null,
                    activeColor: c.primary,
                    checkColor: c.onPrimary,
                    side: BorderSide(color: c.outlineStrong, width: 2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                SizedBox(width: t.space.s),
                Expanded(child: Text(label, style: t.text.bodyL)),
                if (count != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: t.space.s,
                      vertical: t.space.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceSunken,
                      borderRadius: BorderRadius.circular(t.radius.pill),
                    ),
                    child: DkNumberText(
                      '$count',
                      style: t.text.labelM.copyWith(color: c.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
