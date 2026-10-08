import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';

/// Where the privacy line sits: under a tool's title, or on Home.
enum DkPrivacyContext { tool, home }

/// The privacy line (DK-0110; UI spec §11.3): the phone icon (16) and
/// "Processed on this phone" (tools) or "Everything stays on this phone"
/// (Home) in `type.caption` `color.textSecondary`, left-aligned under a title.
class DkPrivacyLine extends StatelessWidget {
  const DkPrivacyLine({super.key, this.where = DkPrivacyContext.tool});

  final DkPrivacyContext where;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: t.space.xs,
      children: [
        ExcludeSemantics(
          child: DkIcon(
            DkIcons.privacy,
            size: DkIconSize.s,
            color: t.color.iconSecondary,
          ),
        ),
        Flexible(
          child: Text(
            where == DkPrivacyContext.tool
                ? l.privacy_line_tool
                : l.privacy_line_home,
            style: t.text.caption.copyWith(color: t.color.textSecondary),
          ),
        ),
      ],
    );
  }
}
