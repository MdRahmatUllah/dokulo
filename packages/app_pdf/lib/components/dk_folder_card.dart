import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_folder_tags.dart';
import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'dk_ring.dart';
import 'dk_tappable.dart';

/// A folder (DK-0088; UI spec §11.2) in Files: a 64 dp list row (a 40 dp
/// folder icon tinted with its colour tag, the name in `type.titleS`, "8
/// files" in `type.caption`), or with [grid] a 3:4 tile with a large folder
/// glyph. While a file is dragged over it ([dropTarget]) it has the 2 dp
/// `color.primary` ring.
class DkFolderCard extends StatelessWidget {
  const DkFolderCard({
    super.key,
    required this.name,
    required this.files,
    required this.onTap,
    this.tag,
    this.grid = false,
    this.dropTarget = false,
    this.onMore,
  });

  final String name;
  final int files;
  final VoidCallback onTap;
  final DkFolderTag? tag;
  final bool grid;
  final bool dropTarget;

  /// The folder menu; no more button when null.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final meta = l.meta_files(files);
    final ink = DkFolderTag.of(tag, t);
    // The card says the name and the count itself (below).
    final title = ExcludeSemantics(
      child: Text(
        name,
        maxLines: grid ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        style: t.text.titleS.copyWith(color: c.textPrimary),
      ),
    );
    final caption = ExcludeSemantics(
      child: Text(meta, style: t.text.caption.copyWith(color: c.textSecondary)),
    );
    final more = onMore == null
        ? null
        : Semantics(
            container: true, // its own button inside the card's node
            button: true,
            label: MaterialLocalizations.of(context).moreButtonTooltip,
            excludeSemantics: true,
            onTap: onMore,
            child: DkTappable(
              onTap: onMore,
              radius: 24,
              builder: (context, pressed) => SizedBox.square(
                dimension: 48,
                child: Center(
                  child: DkIcon(
                    DkIcons.overflow(context),
                    color: c.iconSecondary,
                  ),
                ),
              ),
            ),
          );

    final Widget body = grid
        ? DecoratedBox(
            decoration: t.surfaceAt(
              DkLevel.flat,
              radius: BorderRadius.circular(t.radius.m),
            ),
            child: Padding(
              padding: EdgeInsets.all(t.space.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Center(
                      child: Icon(DkIcons.folder, size: 64, color: ink),
                    ),
                  ),
                  title,
                  caption,
                ],
              ),
            ),
          )
        : Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: EdgeInsets.only(left: t.space.l),
            child: Row(
              spacing: t.space.m,
              children: [
                Icon(DkIcons.folder, size: 40, color: ink),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [title, caption],
                  ),
                ),
                ?more,
              ],
            ),
          );

    // One node for the card (DkTappable gives it the tap and focus), with
    // More as a child node of its own.
    return Semantics(
      container: true,
      button: true,
      label: '$name\n$meta',
      child: DkTappable(
        onTap: onTap,
        radius: t.radius.m,
        builder: (context, pressed) => DkRing(
          side: dropTarget ? t.selectionRing : null,
          radius: t.radius.m,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: pressed ? t.state.pressed : null,
              borderRadius: BorderRadius.circular(t.radius.m),
            ),
            child: body,
          ),
        ),
      ),
    );
  }
}
