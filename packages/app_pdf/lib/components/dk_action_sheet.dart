import 'package:flutter/material.dart';

import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'dk_ring.dart';
import 'dk_sheet.dart';

/// One row of a [DkActionSheet]: an icon and a label.
class DkAction {
  const DkAction({
    this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.tool = false,
    this.checked = false,
    this.trailing,
    this.filled = false,
    this.below,
  });

  /// Under the row, in its padding: the folder menu's colour swatches.
  final Widget? below;

  /// The icon filled: a state that is on (a favourite's star, DK-0280).
  final bool filled;

  /// None in an options menu (F1's sort): the label and the check.
  final IconData? icon;
  final String label;

  /// Runs after the sheet has closed.
  final VoidCallback onTap;

  /// Delete and the like: `color.danger`, always in the last group.
  final bool destructive;

  /// A tool ("Compress PDF"): its icon sits in a 32 tonal square, as in the
  /// Tools tab.
  final bool tool;

  /// A chosen option (a menu's sort order): a check at the end.
  final bool checked;

  /// A Pro badge or a chevron.
  final Widget? trailing;
}

/// The file the actions are about: a 40 thumbnail, the name, the meta line
/// ("2.4 MB · 12 pages · Today 14:32").
class DkActionSheetHeader extends StatelessWidget {
  const DkActionSheetHeader({
    super.key,
    required this.thumbnail,
    required this.name,
    required this.meta,
  });

  /// A DkPageThumb-style page, or a folder icon.
  final Widget thumbnail;
  final String name;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        SizedBox(width: 40, child: thumbnail),
        SizedBox(width: t.space.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: t.text.titleS.copyWith(color: t.color.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                meta,
                style: t.text.caption.copyWith(color: t.color.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Opens a [DkActionSheet] (UI spec §11.7; DK-0184), at the medium detent
/// (§16.3). A row closes the sheet, then runs its action.
Future<void> showDkActionSheet(
  BuildContext context, {
  DkActionSheetHeader? header,
  Widget? top,
  required List<List<DkAction>> groups,
  DkSheetDetent detent = DkSheetDetent.medium,
}) => showDkSheet<void>(
  context,
  detent: detent,
  body: DkActionSheet(header: header, top: top, groups: groups),
);

/// A [DkSheet]'s content for "what to do with this": [header], an optional
/// [top] (e.g. Open and Share buttons), then [groups] of rows between
/// dividers. Destructive rows are moved to a last group, in `color.danger`.
class DkActionSheet extends StatelessWidget {
  const DkActionSheet({
    super.key,
    this.header,
    this.top,
    required this.groups,
    this.closeOnTap = true,
  });

  final DkActionSheetHeader? header;
  final Widget? top;
  final List<List<DkAction>> groups;

  /// A row closes the sheet before its action (off where it isn't in a
  /// route of its own, as in the catalogue).
  final bool closeOnTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ordered = [
      for (final g in groups)
        if (g.any((a) => !a.destructive)) [...g.where((a) => !a.destructive)],
      if (groups.expand((g) => g).any((a) => a.destructive))
        [...groups.expand((g) => g).where((a) => a.destructive)],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) ...[header!, SizedBox(height: t.space.m)],
        if (top != null) ...[top!, SizedBox(height: t.space.s)],
        for (final (i, group) in ordered.indexed) ...[
          if (i > 0)
            Padding(
              padding: EdgeInsets.symmetric(vertical: t.space.xs),
              child: Divider(height: 1, thickness: 1, color: t.divider.color),
            ),
          for (final action in group) DkActionRow(action, close: closeOnTap),
        ],
      ],
    );
  }
}

/// A row of [DkActionSheet] and DkMenu: icon 20 + `bodyL`, at least
/// [minHeight] tall (48 in a sheet, 44 in a menu). Tapping it closes the
/// sheet or menu ([close]), then runs the action.
class DkActionRow extends StatefulWidget {
  const DkActionRow(
    this.action, {
    super.key,
    this.close = true,
    this.minHeight = 48,
    this.padding = EdgeInsets.zero,
  });

  final DkAction action;
  final bool close;
  final double minHeight;
  final EdgeInsetsGeometry padding;

  @override
  State<DkActionRow> createState() => _DkActionRowState();
}

class _DkActionRowState extends State<DkActionRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = widget.action;
    final ink = a.destructive ? t.color.danger : t.color.textPrimary;
    final icon = DkIcon(
      a.icon ?? DkIcons.check,
      size: DkIconSize.m,
      filled: a.filled,
      color: a.destructive
          ? t.color.danger
          : a.tool
          ? t.color.onPrimaryContainer
          : t.color.iconPrimary,
    );
    // InkWell gives the tap; screen readers also need to hear "button".
    final row = Semantics(
      button: true,
      // A chosen sort order reads as "checked", as Material's
      // CheckedPopupMenuItem does; other rows have no checked state.
      checked: a.checked ? true : null,
      child: DkRing(
        side: _focused ? t.focusRing : null,
        radius: 0,
        child: InkWell(
          onTap: () {
            if (widget.close) Navigator.pop(context);
            a.onTap();
          },
          onFocusChange: (v) => setState(() => _focused = v),
          overlayColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.pressed)
                ? t.state.pressed
                : s.contains(WidgetState.hovered)
                ? t.state.hover
                : null,
          ),
          splashFactory: NoSplash.splashFactory,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.minHeight),
            child: Padding(
              padding: widget.padding,
              child: Row(
                children: [
                  if (a.tool)
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.color.primaryContainer,
                        borderRadius: BorderRadius.circular(t.radius.s),
                      ),
                      child: icon,
                    )
                  else if (a.icon != null)
                    icon,
                  if (a.icon != null) SizedBox(width: t.space.m),
                  Expanded(
                    child: Text(
                      a.label,
                      style: t.text.bodyL.copyWith(color: ink),
                    ),
                  ),
                  ?a.trailing,
                  if (a.checked)
                    DkIcon(
                      DkIcons.check,
                      size: DkIconSize.m,
                      color: t.color.primary,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final below = a.below;
    if (below == null) return row;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        Padding(
          padding: widget.padding.add(EdgeInsets.only(bottom: t.space.s)),
          child: below,
        ),
      ],
    );
  }
}
