import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';
import 'dk_tappable.dart';

/// A text action in a bar: Cancel and Done in the editing top bar (UI spec
/// §11.6), Next field and Done over the keyboard (§12.7). `labelL` in
/// `color.primary`, [bold] for Done, a 48 dp target, on DkTappable.
class DkTextAction extends StatelessWidget {
  const DkTextAction({
    super.key,
    required this.label,
    required this.onTap,
    this.bold = false,
    this.danger = false,
  });

  final String label;

  /// Null: disabled.
  final VoidCallback? onTap;
  final bool bold;

  /// `color.danger`: R1's Empty.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: DkTappable(
        onTap: onTap,
        radius: t.radius.s,
        builder: (context, pressed) => Container(
          constraints: const BoxConstraints(
            minWidth: kMinInteractiveDimension,
            minHeight: kMinInteractiveDimension,
          ),
          padding: EdgeInsets.symmetric(horizontal: t.space.m),
          decoration: BoxDecoration(
            color: pressed ? t.state.pressed : null,
            borderRadius: BorderRadius.circular(t.radius.s),
          ),
          // Centred, but only as wide as the label: the title needs the rest.
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.text.labelL.copyWith(
                color: onTap == null
                    ? t.color.textDisabled
                    : danger
                    ? t.color.danger
                    : t.color.primary,
                fontWeight: bold ? FontWeight.w700 : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
