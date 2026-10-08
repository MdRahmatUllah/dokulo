import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';
import 'dk_button.dart';
import 'dk_icon.dart';

/// A banner's kind (UI spec §11.7): its fill and icon.
enum DkBannerVariant { info, warning, error, pro }

/// A note inside the content (UI spec §11.7; DK-0192): `radius.m`, 12
/// padding, a 20 icon, the text in `bodyM`, an optional compact tertiary
/// [action]. Info on `primaryContainer`, warning, error, and Pro on
/// `proContainer`; the icon carries the kind, so colour is never the only
/// cue.
class DkBanner extends StatelessWidget {
  const DkBanner({
    super.key,
    required this.text,
    this.variant = DkBannerVariant.info,
    this.action,
    this.onAction,
  }) : assert((action == null) == (onAction == null), 'an action needs both');

  final String text;
  final DkBannerVariant variant;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final (fill, ink, icon) = switch (variant) {
      DkBannerVariant.info => (
        c.primaryContainer,
        c.onPrimaryContainer,
        DkIcons.info,
      ),
      DkBannerVariant.warning => (
        c.warningContainer,
        c.warning,
        DkIcons.warning,
      ),
      DkBannerVariant.error => (c.dangerContainer, c.danger, DkIcons.error),
      DkBannerVariant.pro => (c.proContainer, c.pro, DkIcons.pro),
    };
    return Container(
      padding: EdgeInsets.all(t.space.m),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(t.radius.m),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: t.space.m,
        children: [
          DkIcon(icon, size: DkIconSize.m, color: ink),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: t.text.bodyM.copyWith(color: c.textPrimary)),
                if (action != null)
                  DkButton(
                    label: action!,
                    onPressed: onAction,
                    variant: DkButtonVariant.tertiary,
                    size: DkButtonSize.compact,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
