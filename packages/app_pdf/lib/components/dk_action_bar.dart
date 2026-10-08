import 'package:flutter/material.dart';

import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';
import 'dk_button.dart';
import 'dk_number_text.dart';

/// The sticky bottom of a tool or flow (UI spec §11.6; DK-0170): `surface`
/// with a top hairline, 16 / 12 padding and the safe area below; one large
/// full-width button, optionally a secondary above it ([secondaryBeside]:
/// to its left), and an optional [caption] above the button ("About 1.8 MB
/// · 12 pages", "Free try · Pro unlocks unlimited use").
///
/// Put it in the Scaffold's `bottomNavigationBar`, so toasts float above it.
/// It rides on top of the keyboard (§10, §12.7): Scaffold doesn't lift a
/// `bottomNavigationBar`, so the bar pads itself by the keyboard's height.
class DkActionBar extends StatelessWidget {
  const DkActionBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.destructive = false,
    this.caption,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryBeside = false,
  });

  /// Verb + object (+ number): "Compress 12 pages".
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  /// "Delete forever", "Apply redaction": the primary in `color.danger`.
  final bool destructive;

  /// Numbers keep their width as they change (tabular figures).
  final String? caption;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool secondaryBeside;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final primary = DkButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      loading: loading,
      size: DkButtonSize.large,
      variant: destructive
          ? DkButtonVariant.destructive
          : DkButtonVariant.primary,
      expand: true,
    );
    final secondary = secondaryLabel == null
        ? null
        : DkButton(
            label: secondaryLabel!,
            onPressed: onSecondary,
            size: DkButtonSize.large,
            variant: DkButtonVariant.secondary,
            expand: true,
          );
    // At 150 % text and more, side by side leaves each label too little
    // room: stack them.
    final beside =
        secondaryBeside && MediaQuery.textScalerOf(context).scale(1) < 1.5;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.color.surface,
        border: Border(top: t.divider),
      ),
      child: SafeArea(
        top: false,
        // Over the keyboard, the home indicator's inset is under it already.
        minimum: EdgeInsets.only(bottom: t.space.m + keyboard),
        child: Padding(
          padding: EdgeInsets.fromLTRB(t.space.l, t.space.m, t.space.l, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: t.space.s,
            children: [
              if (caption != null)
                DkNumberText(
                  caption!,
                  style: t.text.caption.copyWith(color: t.color.textSecondary),
                  textAlign: TextAlign.center,
                ),
              if (secondary != null && !beside) secondary,
              if (secondary != null && beside)
                Row(
                  spacing: t.space.s,
                  children: [
                    Expanded(child: secondary),
                    Expanded(child: primary),
                  ],
                )
              else
                primary,
            ],
          ),
        ),
      ),
    );
  }
}
