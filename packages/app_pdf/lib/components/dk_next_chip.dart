import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import '../tools/tool_catalogue.dart';
import 'dk_icon.dart';
import 'dk_tappable.dart';

/// "What next" on a result screen (DK-0106; UI spec §11.3): a 36 dp chip on
/// `color.surface` with a 1 dp `color.outline`, the tool's icon (18), its
/// name and a 16 dp arrow. 48 dp to touch. [DkNextChip.custom] is the same
/// chip for an action that isn't a tool ("Save as workflow", §20.4).
class DkNextChip extends StatelessWidget {
  const DkNextChip({
    super.key,
    required String this.toolId,
    required this.onTap,
  }) : icon = null,
       label = null;

  const DkNextChip.custom({
    super.key,
    required IconData this.icon,
    required String this.label,
    required this.onTap,
  }) : toolId = null;

  final String? toolId;
  final IconData? icon;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final tool = toolId == null ? null : ToolCatalogue.of(toolId!);
    final name = label ?? tool!.name(AppLocalizations.of(context));
    return Semantics(
      button: true,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: DkTappable(
            onTap: onTap,
            radius: t.radius.pill,
            builder: (context, pressed) => Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: EdgeInsets.symmetric(horizontal: t.space.m),
              decoration: BoxDecoration(
                color: pressed
                    ? Color.alphaBlend(t.state.pressed, c.surface)
                    : c.surface,
                borderRadius: BorderRadius.circular(t.radius.pill),
                border: Border.all(color: c.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: t.space.s,
                children: [
                  Icon(icon ?? tool!.icon, size: 18, color: c.iconPrimary),
                  Flexible(
                    child: Text(
                      name,
                      style: t.text.labelL.copyWith(color: c.textPrimary),
                    ),
                  ),
                  DkIcon(
                    DkIcons.arrowForward,
                    size: DkIconSize.s,
                    color: c.iconSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
