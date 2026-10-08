import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'dk_tappable.dart';

/// A settings row (DK-0100; UI spec §11.2): 56 dp (72 with a description),
/// an optional 24 dp icon, the [title] in `type.bodyL`, the [description] in
/// `type.bodyM` `color.textSecondary`, and at the end the [trailing] control
/// (a DkSwitch), or the [value] text and a chevron, or a chevron alone when
/// [onTap] opens a page. Put rows in a [DkSettingsGroup].
class DkSettingsRow extends StatelessWidget {
  const DkSettingsRow({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.value,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? description;
  final IconData? icon;

  /// The current choice, shown before the chevron ("System").
  final String? value;

  /// A control instead of the chevron (a DkSwitch).
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final row = Container(
      constraints: BoxConstraints(minHeight: description == null ? 56 : 72),
      padding: EdgeInsets.symmetric(horizontal: t.space.l, vertical: t.space.s),
      child: Row(
        spacing: t.space.m,
        children: [
          if (icon != null) DkIcon(icon!, color: c.iconPrimary),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: t.text.bodyL.copyWith(color: c.textPrimary)),
                if (description != null)
                  Text(
                    description!,
                    style: t.text.bodyM.copyWith(color: c.textSecondary),
                  ),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else ...[
            if (value != null)
              Text(
                value!,
                style: t.text.bodyM.copyWith(color: c.textSecondary),
              ),
            if (onTap != null)
              DkIcon(DkIcons.chevronRight, color: c.iconSecondary),
          ],
        ],
      ),
    );
    // One node for screen readers: the title, the description, the value,
    // and the switch's state when there is one.
    return MergeSemantics(
      child: Semantics(
        button: onTap != null && trailing == null,
        onTap: onTap,
        child: DkTappable(
          onTap: onTap,
          radius: 0,
          builder: (context, pressed) => DecoratedBox(
            decoration: BoxDecoration(color: pressed ? t.state.pressed : null),
            child: row,
          ),
        ),
      ),
    );
  }
}

/// A group of settings rows (UI spec §11.2): the [title] in `type.labelM`
/// `color.textSecondary` (sentence case), 24 above and 8 below, then the
/// rows on a `color.surface` card (`radius.m`) with dividers between them.
class DkSettingsGroup extends StatelessWidget {
  const DkSettingsGroup({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              t.space.l,
              t.space.xl,
              t.space.l,
              t.space.s,
            ),
            child: Semantics(
              header: true,
              child: Text(
                title!,
                style: t.text.labelM.copyWith(color: c.textSecondary),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(t.radius.m),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, indent: t.space.l, color: c.outline),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
