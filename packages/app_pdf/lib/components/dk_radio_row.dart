import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';

/// A radio choice (DK-0146; UI spec §11.4): a 24 dp radio, the [label] in
/// `type.bodyL` and an optional [description]. The whole row selects; put
/// rows under a `RadioGroup<T>`.
class DkRadioRow<T> extends StatelessWidget {
  const DkRadioRow({
    super.key,
    required this.value,
    required this.label,
    this.description,
  });

  final T value;
  final String label;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final group = RadioGroup.maybeOf<T>(context);
    return MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: group == null ? null : () => group.onChanged(value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 40,
                child: Radio<T>(
                  value: value,
                  activeColor: c.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
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
                          style: t.text.bodyM.copyWith(color: c.textSecondary),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
