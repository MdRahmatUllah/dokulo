import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import '../tools/tool_catalogue.dart';
import 'dk_icon.dart';
import 'dk_pro_badge.dart';
import 'dk_status_dot.dart';
import 'dk_tappable.dart';

/// How long a new tool keeps its dot (UI spec §11.2).
const _newFor = Duration(days: 14);

/// A tool in the Tools grid and on Home (DK-0082; UI spec §11.2): 96 dp tall,
/// at least 76 wide, filling its grid cell. A 48 dp `color.primaryContainer`
/// square (`radius.m`) with the tool's icon (28, `onPrimaryContainer`), the
/// name below in `type.labelM` (two lines at most). A Pro tool has the small
/// DkProBadge on the square's top-right corner, and is never greyed out. A
/// tool added less than 14 days ago ([addedOn]) has the 8 dp "new" dot.
/// Screen readers hear "Compress PDF", "Black out, Pro" or "Smart split, New".
class DkToolTile extends StatelessWidget {
  const DkToolTile({
    super.key,
    required this.toolId,
    required this.onTap,
    this.onLongPress,
    this.addedOn,
    this.now,
    this.showPressed = false,
  });

  final String toolId;
  final VoidCallback onTap;

  /// The tile menu (Unpin, About this tool).
  final VoidCallback? onLongPress;

  /// When the tool came out; null for the original tools.
  final DateTime? addedOn;

  /// The clock, for tests; defaults to now.
  final DateTime? now;

  /// Draw the pressed state without a finger: catalogue and goldens only.
  final bool showPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final tool = ToolCatalogue.of(toolId);
    final name = tool.name(l);
    final added = addedOn;
    final isNew =
        added != null && (now ?? DateTime.now()).difference(added) < _newFor;
    final shape = BorderRadius.circular(t.radius.m);
    return Semantics(
      button: true,
      label: [
        name,
        if (tool.isPro) l.pro_badge,
        if (isNew) l.status_new,
      ].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: DkTappable(
        onTap: onTap,
        onLongPress: onLongPress,
        radius: t.radius.m,
        showPressed: showPressed,
        builder: (context, pressed) => Container(
          constraints: const BoxConstraints(minWidth: 76, minHeight: 96),
          decoration: BoxDecoration(
            color: pressed ? t.state.pressed : null,
            borderRadius: shape,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: t.space.xs,
            vertical: t.space.s,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.primaryContainer,
                      borderRadius: shape,
                    ),
                    child: Center(
                      child: DkIcon(
                        tool.icon,
                        size: DkIconSize.xl,
                        color: c.onPrimaryContainer,
                      ),
                    ),
                  ),
                  if (tool.isPro)
                    const Positioned(top: -4, right: -4, child: _CornerBadge()),
                  if (isNew)
                    const Positioned(
                      top: -2,
                      left: -2,
                      child: DkStatusDot(DkStatus.fresh),
                    ),
                ],
              ),
              SizedBox(height: t.space.xs),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: t.text.labelM.copyWith(color: c.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tool in a list (DK-0084; UI spec §11.2): the share picker and search
/// results. 56 dp tall (more with the description): a 40 dp icon square, the
/// name in `type.titleS`, an optional one-line description in `type.bodyM`
/// `color.textSecondary`, the Pro badge, a chevron.
class DkToolRow extends StatelessWidget {
  const DkToolRow({
    super.key,
    required this.toolId,
    required this.onTap,
    this.showDescription = false,
  });

  final String toolId;
  final VoidCallback onTap;
  final bool showDescription;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final tool = ToolCatalogue.of(toolId);
    final name = tool.name(l);
    return Semantics(
      button: true,
      label: [
        tool.isPro ? '$name, ${l.pro_badge}' : name,
        if (showDescription) tool.description(l),
      ].join('\n'),
      excludeSemantics: true,
      onTap: onTap,
      child: DkTappable(
        onTap: onTap,
        radius: 0,
        builder: (context, pressed) => Container(
          constraints: const BoxConstraints(minHeight: 56),
          color: pressed ? t.state.pressed : null,
          padding: EdgeInsets.symmetric(
            horizontal: t.space.l,
            vertical: t.space.s,
          ),
          child: Row(
            spacing: t.space.m,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.primaryContainer,
                  borderRadius: BorderRadius.circular(t.radius.s),
                ),
                child: Center(
                  child: DkIcon(tool.icon, color: c.onPrimaryContainer),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: t.text.titleS.copyWith(color: c.textPrimary),
                    ),
                    if (showDescription)
                      Text(
                        tool.description(l),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.text.bodyM.copyWith(color: c.textSecondary),
                      ),
                  ],
                ),
              ),
              if (tool.isPro) const _CornerBadge(small: false),
              DkIcon(DkIcons.chevronRight, color: c.iconSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Pro badge with its text held: a corner mark that grew with the text
/// would cover the next tile at 200 % (§28), so the tile's small one stays
/// at 100 % (as iOS badges do) and the row's at 130 %; the names still scale.
class _CornerBadge extends StatelessWidget {
  const _CornerBadge({this.small = true});

  final bool small;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: small ? 1 : 1.3,
    child: DkProBadge(small: small),
  );
}
