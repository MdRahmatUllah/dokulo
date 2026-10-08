import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';

/// The Pro badge (DK-0102; UI spec §11.3): a `color.proContainer` pill with
/// the `workspace_premium` icon and the word "Pro" in `color.pro`. The word
/// is always there, never the icon alone. 20 dp tall, or 16 with [small]
/// (on tool tiles).
class DkProBadge extends StatelessWidget {
  const DkProBadge({super.key, this.small = false});

  final bool small;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      constraints: BoxConstraints(minHeight: small ? 16 : 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: t.color.proContainer,
        borderRadius: BorderRadius.circular(t.radius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: t.space.xxs,
        children: [
          ExcludeSemantics(
            child: Icon(DkIcons.pro, size: 12, color: t.color.pro),
          ),
          Text(
            AppLocalizations.of(context).pro_badge,
            style: t.text.labelM.copyWith(color: t.color.pro, height: 1),
          ),
        ],
      ),
    );
  }
}
