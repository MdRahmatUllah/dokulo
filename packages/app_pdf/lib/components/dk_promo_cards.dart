import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_button.dart';
import 'dk_icon.dart';
import 'dk_tappable.dart';

/// The × that dismisses a card: 20 dp, 44 to touch, "Close" for screen
/// readers.
class _Close extends StatelessWidget {
  const _Close({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: MaterialLocalizations.of(context).closeButtonTooltip,
    excludeSemantics: true,
    onTap: onTap,
    child: DkTappable(
      onTap: onTap,
      radius: 22,
      builder: (context, pressed) => SizedBox.square(
        dimension: 44,
        child: Center(
          child: DkIcon(
            DkIcons.close,
            size: DkIconSize.m,
            color: context.tokens.color.iconSecondary,
          ),
        ),
      ),
    ),
  );
}

/// "Continue where you left off" on Home (DK-0096; UI spec §11.2): a
/// full-width `color.primaryContainer` card at 60 % (`radius.m`, 12
/// padding) with the scan or tool [icon] (32), the [title] in `type.titleS`,
/// the [sub] line in `type.caption`, a compact primary button ([action]:
/// "Continue" / "Open") and the × that dismisses it.
class DkContinueCard extends StatelessWidget {
  const DkContinueCard({
    super.key,
    required this.icon,
    required this.title,
    required this.sub,
    required this.action,
    required this.onAction,
    required this.onDismiss,
  });

  final IconData icon;
  final String title, sub, action;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    return Container(
      decoration: BoxDecoration(
        color: c.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(t.radius.m),
      ),
      child: Stack(
        children: [
          Padding(
            // Room on the right for the × in the corner.
            padding: EdgeInsets.fromLTRB(t.space.m, t.space.m, 40, t.space.m),
            child: Row(
              spacing: t.space.m,
              children: [
                Icon(icon, size: 32, color: c.onPrimaryContainer),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: t.text.titleS.copyWith(color: c.textPrimary),
                      ),
                      Text(
                        sub,
                        style: t.text.caption.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                DkButton(
                  label: action,
                  onPressed: onAction,
                  size: DkButtonSize.compact,
                ),
              ],
            ),
          ),
          Positioned(top: 0, right: 0, child: _Close(onTap: onDismiss)),
        ],
      ),
    );
  }
}

/// The Pro card (DK-0098; UI spec §11.2): `color.proContainer`, `radius.m`,
/// 16 padding; the `workspace_premium` icon (24, `color.pro`), "Unlock every
/// tool, for good" in `type.titleS`, the line in `type.bodyM`, and the
/// tertiary "See Pro" button. On Home it has the × ([onDismiss]); on Me it
/// has none. No animation.
class DkProCard extends StatelessWidget {
  const DkProCard({super.key, required this.onOpen, this.onDismiss});

  /// Opens the paywall (X3).
  final VoidCallback onOpen;

  /// Null: no × (the Me screen).
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        t.space.l,
        t.space.l,
        onDismiss == null ? t.space.l : 0,
        t.space.s,
      ),
      decoration: BoxDecoration(
        color: c.proContainer,
        borderRadius: BorderRadius.circular(t.radius.m),
      ),
      // The column starts 8 dp early, so the tertiary button's own padding
      // lines its label up with the text while its whole target stays inside
      // the column (a Transform would leave 8 dp that take no touches); the
      // title and body take those 8 dp back.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(DkIcons.pro, size: 24, color: c.pro),
          SizedBox(width: t.space.m - t.space.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: t.space.xs,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: t.space.s),
                  child: Text(
                    l.pro_card_title,
                    style: t.text.titleS.copyWith(color: c.textPrimary),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: t.space.s),
                  child: Text(
                    l.pro_card_body,
                    style: t.text.bodyM.copyWith(color: c.textSecondary),
                  ),
                ),
                DkButton(
                  label: l.pro_card_action,
                  onPressed: onOpen,
                  variant: DkButtonVariant.tertiary,
                  size: DkButtonSize.compact,
                ),
              ],
            ),
          ),
          if (onDismiss != null) SizedBox(width: t.space.m),
          if (onDismiss != null) _Close(onTap: onDismiss!),
        ],
      ),
    );
  }
}
