import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'dk_tappable.dart';
import 'dk_text_rules.dart';

/// How a file card lays out (UI spec §11.2).
enum DkFileCardVariant {
  /// A 72 dp row in Files and Recents.
  list,

  /// A tile in the Files grid.
  grid,

  /// A 120 dp card in Home's recents carousel.
  compact,
}

/// What the file is: a PDF and an image show their page; HTML shows a page
/// with the `language` icon.
enum DkFileKind { pdf, image, html }

/// A file (DK-0086; UI spec §11.2).
/// - [DkFileCardVariant.list]: 72 dp; a 44 × 56 thumbnail (`radius.xs`, 1 dp
///   outline), the name in `type.titleS` cut in the middle so ".pdf" stays,
///   the [meta] line ("2.4 MB · 12 pages · Today 14:32") in `type.caption`,
///   and the more button. Rows have no card, only the list's dividers.
/// - [DkFileCardVariant.grid]: the page centred in a 3:4 area on
///   `color.surfaceSunken`, the name (two lines) and the meta (one); the more
///   button is a 28 dp tonal circle on the thumbnail's top-right.
/// - [DkFileCardVariant.compact]: 120 wide, a 120 × 150 thumbnail, the name
///   on one line.
///
/// States: pressed; in multi-select ([selected] not null) a 24 dp circle on
/// the thumbnail's top-left, filled with a check when selected, and a
/// `primaryContainer` row tint; [locked] blurs the thumbnail with a lock on
/// it; [progress] draws a 2 dp `color.primary` line along the bottom;
/// [encrypted] puts a 16 dp lock after the meta. While [thumbnail] is null
/// (it renders lazily, from doc_core's ThumbnailCache) a skeleton shows.
class DkFileCard extends StatefulWidget {
  const DkFileCard({
    super.key,
    required this.name,
    required this.meta,
    required this.onTap,
    this.variant = DkFileCardVariant.list,
    this.kind = DkFileKind.pdf,
    this.thumbnail,
    this.onLongPress,
    this.onMore,
    this.selected,
    this.locked = false,
    this.encrypted = false,
    this.progress,
    this.showPressed = false,
    this.semanticsActions,
  });

  final String name;

  /// "2.4 MB · 12 pages · Today 14:32", built by the caller with the l10n
  /// formatters.
  final String meta;
  final VoidCallback onTap;
  final DkFileCardVariant variant;
  final DkFileKind kind;

  /// The rendered first page or the image; null while it loads.
  final Widget? thumbnail;

  /// Starts multi-select.
  final VoidCallback? onLongPress;

  /// The file menu; no more button when null.
  final VoidCallback? onMore;

  /// Null: not in multi-select. False/true: the empty or checked circle.
  final bool? selected;
  final bool locked;
  final bool encrypted;

  /// A job is working on the file: 0–1, shown as the line along the bottom.
  final double? progress;

  /// Draw the pressed state without a finger: catalogue and goldens only.
  final bool showPressed;

  /// Screen-reader actions on the card's node (selection mode's "Select").
  final Map<CustomSemanticsAction, VoidCallback>? semanticsActions;

  @override
  State<DkFileCard> createState() => _DkFileCardState();
}

class _DkFileCardState extends State<DkFileCard> {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final w = widget;
    final thumbSize = switch (w.variant) {
      DkFileCardVariant.list => const Size(44, 56),
      DkFileCardVariant.compact => const Size(120, 150),
      DkFileCardVariant.grid => null, // the cell's width, 3:4
    };

    Widget page = switch ((w.kind, w.thumbnail)) {
      (DkFileKind.html, _) => Container(
        color: c.pageWhite,
        alignment: Alignment.center,
        child: DkIcon(DkIcons.language, color: c.iconSecondary),
      ),
      (_, final Widget thumb) => ColorFiltered(
        colorFilter: t.thumbnailFilter,
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: thumb,
        ),
      ),
      // Loading: a skeleton block.
      (_, null) => ColoredBox(color: c.surfaceSunken),
    };
    if (w.locked) {
      page = Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: page,
          ),
          Center(
            child: DkIcon(
              DkIcons.lock,
              size: DkIconSize.m,
              color: c.iconPrimary,
            ),
          ),
        ],
      );
    }
    final radius = BorderRadius.circular(t.radius.xs);
    Widget thumb = ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: c.outline),
        ),
        child: page,
      ),
    );
    thumb = thumbSize == null
        ? Container(
            color: c.surfaceSunken,
            padding: EdgeInsets.all(t.space.m),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Center(
                child: AspectRatio(aspectRatio: 1 / 1.414, child: thumb),
              ),
            ),
          )
        : SizedBox.fromSize(size: thumbSize, child: thumb);

    final check = w.selected == null
        ? null
        : Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: w.selected! ? c.primary : c.surface,
              border: w.selected!
                  ? null
                  : Border.all(color: c.outlineStrong, width: 2),
            ),
            child: w.selected!
                ? DkIcon(DkIcons.check, size: DkIconSize.s, color: c.onPrimary)
                : null,
          );
    final more = w.onMore == null
        ? null
        : Semantics(
            container: true, // its own button inside the card's node
            button: true,
            label: MaterialLocalizations.of(context).moreButtonTooltip,
            excludeSemantics: true,
            onTap: w.onMore,
            child: DkTappable(
              onTap: w.onMore,
              radius: 24,
              builder: (context, pressed) => SizedBox.square(
                dimension: 48,
                child: Center(
                  child: w.variant == DkFileCardVariant.grid
                      ? Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.primaryContainer,
                          ),
                          child: Icon(
                            DkIcons.overflow(context),
                            size: 18,
                            color: c.onPrimaryContainer,
                          ),
                        )
                      : DkIcon(
                          DkIcons.overflow(context),
                          color: c.iconSecondary,
                        ),
                ),
              ),
            ),
          );
    thumb = Stack(
      clipBehavior: Clip.none,
      children: [
        thumb,
        if (check != null) Positioned(top: 4, left: 4, child: check),
        if (more != null && w.variant == DkFileCardVariant.grid)
          // Inside the Stack: Flutter hit-tests only within its bounds, so
          // the whole 48 dp target stays tappable.
          Positioned(top: 0, right: 0, child: more),
      ],
    );

    final nameStyle = t.text.titleS.copyWith(color: c.textPrimary);
    final name = switch (w.variant) {
      DkFileCardVariant.list => DkMiddleEllipsisText(w.name, style: nameStyle),
      DkFileCardVariant.grid => Text(
        w.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: nameStyle,
      ),
      DkFileCardVariant.compact => DkMiddleEllipsisText(
        w.name,
        style: nameStyle,
      ),
    };
    final metaLine = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: t.space.xs,
      children: [
        Flexible(
          child: Text(
            w.meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.text.caption.copyWith(color: c.textSecondary),
          ),
        ),
        if (w.encrypted)
          DkIcon(DkIcons.lock, size: DkIconSize.s, color: c.iconSecondary),
      ],
    );
    final text = ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [name, metaLine],
      ),
    );

    final Widget body = switch (w.variant) {
      DkFileCardVariant.list => Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: EdgeInsets.only(left: t.space.l),
        child: Row(
          spacing: t.space.m,
          children: [
            thumb,
            Expanded(child: text),
            ?more,
          ],
        ),
      ),
      DkFileCardVariant.grid => DecoratedBox(
        decoration: t.surfaceAt(
          DkLevel.flat,
          radius: BorderRadius.circular(t.radius.m),
        ),
        child: Padding(
          padding: EdgeInsets.all(t.space.s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: t.space.xs,
            children: [thumb, text],
          ),
        ),
      ),
      DkFileCardVariant.compact => SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: t.space.xs,
          children: [thumb, text],
        ),
      ),
    };

    // One node for the card (DkTappable gives it the tap, long press and
    // focus), with More as a child node of its own.
    return Semantics(
      container: true,
      button: true,
      selected: w.selected,
      customSemanticsActions: w.semanticsActions,
      label: [
        w.name,
        w.meta,
        if (w.locked) l.file_locked,
        if (w.encrypted) l.file_encrypted,
      ].join('\n'),
      child: DkTappable(
        onTap: w.onTap,
        onLongPress: w.onLongPress,
        radius: w.variant == DkFileCardVariant.list ? 0 : t.radius.m,
        showPressed: w.showPressed,
        builder: (context, pressed) => Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: w.selected == true
                    ? c.primaryContainer
                    : (pressed ? t.state.pressed : null),
                borderRadius: w.variant == DkFileCardVariant.list
                    ? null
                    : BorderRadius.circular(t.radius.m),
              ),
              child: body,
            ),
            if (w.progress != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: w.progress,
                  minHeight: 2,
                  color: c.primary,
                  backgroundColor: Colors.transparent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
