import 'package:flutter/material.dart';

import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';
import 'dk_button.dart';
import 'dk_icon.dart';
import 'dk_tappable.dart';
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
    this.onMenu,
    this.menuLabel,
  }) : assert((onMenu == null) == (menuLabel == null), 'a menu needs both');

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

  /// A split button (T3's Save, UI spec §20.4): a chevron segment on the
  /// primary's right opens a menu, anchored to it ([showDkMenu]).
  final void Function(BuildContext anchor)? onMenu;

  /// What screen readers say for the chevron.
  final String? menuLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = Radius.circular(t.radius.l);
    final button = DkButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      loading: loading,
      size: DkButtonSize.large,
      variant: destructive
          ? DkButtonVariant.destructive
          : DkButtonVariant.primary,
      expand: true,
      borderRadius: onMenu == null ? null : BorderRadius.horizontal(left: r),
    );
    final primary = onMenu == null
        ? button
        // The chevron as tall as the button, which grows with large text.
        : IntrinsicHeight(
            child: Row(
              spacing: 1,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: button),
                _MenuSegment(
                  label: menuLabel!,
                  radius: r,
                  onTap: onPressed == null ? null : onMenu!,
                ),
              ],
            ),
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

/// The split button's chevron: 52 wide, the primary's colours, its right
/// corners rounded.
class _MenuSegment extends StatelessWidget {
  const _MenuSegment({
    required this.label,
    required this.radius,
    required this.onTap,
  });

  final String label;
  final Radius radius;
  final void Function(BuildContext anchor)? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final tap = onTap;
    return Semantics(
      button: true,
      enabled: tap != null,
      label: label,
      excludeSemantics: true,
      onTap: tap == null ? null : () => tap(context),
      child: DkTappable(
        onTap: tap == null ? null : () => tap(context),
        radius: radius.x,
        builder: (context, pressed) => Opacity(
          opacity: tap == null ? 0.4 : 1,
          child: Container(
            width: 52,
            constraints: const BoxConstraints(minHeight: 52),
            decoration: BoxDecoration(
              color: pressed ? c.primaryPressed : c.primary,
              borderRadius: BorderRadius.horizontal(right: radius),
            ),
            child: DkIcon(DkIcons.expandMore, color: c.onPrimary),
          ),
        ),
      ),
    );
  }
}
