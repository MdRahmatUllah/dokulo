import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';
import 'dk_tappable.dart';

/// A radio choice (DK-0146; UI spec §11.4): a 24 dp radio, the [label] in
/// `type.bodyL` and an optional [description]. The whole row selects, by
/// finger or keyboard (focus ring, pressed overlay); put rows under a
/// `RadioGroup<T>`.
class DkRadioRow<T> extends StatelessWidget {
  const DkRadioRow({
    super.key,
    required this.value,
    required this.label,
    this.description,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? description;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final group = RadioGroup.maybeOf<T>(context);
    final active = enabled && group != null;
    return MergeSemantics(
      child: DkTappable(
        onTap: active ? () => group.onChanged(value) : null,
        radius: t.radius.s,
        builder: (context, pressed) => Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: pressed ? t.state.pressed : null,
            borderRadius: BorderRadius.circular(t.radius.s),
          ),
          // Dimmed once, here: the radio keeps its enabled colours.
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
                      child: Radio<T>(
                        value: value,
                        enabled: enabled,
                        fillColor: WidgetStateProperty.resolveWith(
                          (s) => s.contains(WidgetState.selected)
                              ? c.primary
                              : c.outlineStrong,
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
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: t.space.s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: t.text.bodyL),
                        if (description != null)
                          Text(
                            description!,
                            style: t.text.bodyM.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                      ],
                    ),
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
