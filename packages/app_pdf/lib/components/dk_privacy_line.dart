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
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final style = t.text.caption.copyWith(color: t.color.textSecondary);
    // The icon centres on the first line, also when large text wraps it.
    final line =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) *
        (style.height ?? 1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: t.space.xs,
      children: [
        ExcludeSemantics(
          child: Padding(
            padding: EdgeInsets.only(
              top: ((line - DkIconSize.s.dp) / 2).clamp(0, double.infinity),
            ),
            child: DkIcon(
              DkIcons.privacy,
              size: DkIconSize.s,
              color: t.color.iconSecondary,
            ),
          ),
        ),
        Flexible(
          // "this tablet" on a tablet (the tablet artboards).
          child: Text(switch ((where, tablet)) {
            (DkPrivacyContext.tool, false) => l.privacy_line_tool,
            (DkPrivacyContext.tool, true) => l.privacy_line_tool_tablet,
            (_, false) => l.privacy_line_home,
            (_, true) => l.privacy_line_home_tablet,
          }, style: style),
        ),
      ],
    );
  }
}
