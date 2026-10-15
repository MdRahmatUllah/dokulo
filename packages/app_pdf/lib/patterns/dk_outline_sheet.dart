import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';

import '../components/dk_sheet.dart';
import '../components/dk_tappable.dart';
import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';

/// The document's outline (bookmarks) as a sheet (DK-0309): each entry
/// with its page number, nested entries indented 16 per level. Returns the
/// 0-based page the user tapped, or null. An entry pointing nowhere in the
/// file is shown but can't be tapped; with no outline the sheet says so.
Future<int?> showOutlineSheet(
  BuildContext context,
  List<OutlineEntry> outline,
) {
  final l = AppLocalizations.of(context);
  return showDkSheet<int>(
    context,
    title: l.viewer_outline_title,
    showClose: true,
    detent: outline.isEmpty ? DkSheetDetent.small : DkSheetDetent.medium,
    body: outline.isEmpty
        ? Builder(
            builder: (context) => Text(
              l.viewer_outline_empty,
              style: context.tokens.text.bodyM.copyWith(
                color: context.tokens.color.textSecondary,
              ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (entry, depth) in _flatten(outline, 0))
                _OutlineRow(entry: entry, depth: depth),
            ],
          ),
  );
}

/// Depth-first, with each entry's nesting level.
Iterable<(OutlineEntry, int)> _flatten(List<OutlineEntry> entries, int depth) =>
    entries.expand((e) => [(e, depth), ..._flatten(e.children, depth + 1)]);

class _OutlineRow extends StatelessWidget {
  const _OutlineRow({required this.entry, required this.depth});

  final OutlineEntry entry;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final page = entry.page;
    final tap = page == null ? null : () => Navigator.pop(context, page);
    return Semantics(
      button: tap != null,
      enabled: tap != null,
      label: page == null
          ? entry.title
          : '${entry.title}, ${l.viewer_page_chip(page + 1)}',
      excludeSemantics: true,
      onTap: tap,
      child: DkTappable(
        onTap: tap,
        radius: t.radius.s,
        builder: (context, pressed) => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: EdgeInsets.only(
              left: t.space.l * depth,
              top: t.space.s,
              bottom: t.space.s,
            ),
            child: Row(
              spacing: t.space.m,
              children: [
                Expanded(
                  child: Text(
                    entry.title,
                    style: (depth == 0 ? t.text.bodyL : t.text.bodyM).copyWith(
                      color: tap == null
                          ? t.color.textSecondary
                          : t.color.textPrimary,
                    ),
                  ),
                ),
                if (page != null)
                  Text(
                    '${page + 1}',
                    style: t.text.caption.copyWith(
                      color: t.color.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
