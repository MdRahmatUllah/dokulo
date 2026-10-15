import 'package:flutter/material.dart';

import '../components/dk_button.dart';
import '../components/dk_icon.dart';
import '../components/dk_icon_button.dart';
import '../components/dk_pro_badge.dart';
import '../components/dk_sheet.dart';
import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import '../tools/tool_catalogue.dart';

/// About this tool (DK-0259; UI spec §20.5): what a tool does, what it needs,
/// what it makes, and that it runs on the phone. From a tile's long-press
/// menu (H1, T1) and T2's overflow. [onOpen] adds "Open {tool}" (not from T2,
/// which is the tool already).
Future<void> showAboutTool(
  BuildContext context,
  ToolInfo tool, {
  VoidCallback? onOpen,
}) {
  final l = AppLocalizations.of(context);
  return showDkSheet<void>(
    context,
    body: DkAboutTool(tool),
    actions: onOpen == null
        ? null
        : Builder(
            builder: (context) => DkButton(
              label: l.about_tool_open(tool.name(l)),
              size: DkButtonSize.large,
              expand: true,
              onPressed: () {
                Navigator.pop(context);
                onOpen();
              },
            ),
          ),
  );
}

/// The sheet's content, also for the catalogue and tests.
class DkAboutTool extends StatelessWidget {
  const DkAboutTool(this.tool, {super.key});

  final ToolInfo tool;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          spacing: t.space.m,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: DkIcon(tool.icon, color: c.onPrimaryContainer),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      tool.name(l),
                      style: t.text.titleM.copyWith(color: c.textPrimary),
                    ),
                  ),
                  if (tool.isPro)
                    const DkProBadge(small: true)
                  else
                    Text(
                      l.tool_tier_free,
                      style: t.text.caption.copyWith(color: c.success),
                    ),
                ],
              ),
            ),
            DkIconButton(
              icon: DkIcons.close,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.maybePop(context),
            ),
          ],
        ),
        SizedBox(height: t.space.l),
        Text(
          tool.description(l),
          style: t.text.bodyM.copyWith(color: c.textPrimary),
        ),
        SizedBox(height: t.space.l),
        _Fact(DkIcons.input, l.about_tool_need, tool.need(l)),
        SizedBox(height: t.space.m),
        _Fact(DkIcons.output, l.about_tool_get, tool.get(l)),
        SizedBox(height: t.space.m),
        if (tool.needsInternet)
          _Fact(DkIcons.internet, l.about_tool_online, l.about_tool_online_sub)
        else
          _Fact(
            DkIcons.privacy,
            l.about_tool_offline,
            l.about_tool_offline_sub,
          ),
      ],
    );
  }
}

/// A 20 dp icon, a label and its line; one node for screen readers.
class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.label, this.text);

  final IconData icon;
  final String label, text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: t.space.m,
        children: [
          DkIcon(icon, size: DkIconSize.m, color: c.iconSecondary),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: t.text.labelM.copyWith(color: c.textPrimary),
                ),
                Text(
                  text,
                  style: t.text.bodyM.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
