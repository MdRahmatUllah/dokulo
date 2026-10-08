import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'dk_page_chip.dart';
import 'dk_tappable.dart';

/// What happened to a piece of text between two versions (UI spec §4.3).
enum DkChange { added, removed, changed }

/// One change in Compare PDFs' list (UI spec §11.8; DK-0218): the change's
/// tag (Added / Removed / Changed with its §4.3 colours and a plus, minus or
/// dot, so colour is never the only cue), the excerpt in `bodyM` (two lines,
/// struck through when removed) and the page chip. Tapping the row jumps to
/// the change; the chip jumps to its page.
class DkDiffRow extends StatelessWidget {
  const DkDiffRow({
    super.key,
    required this.change,
    required this.excerpt,
    required this.page,
    required this.onTap,
  });

  final DkChange change;
  final String excerpt;

  /// 1-based, in the newer version (the older one for removed text).
  final int page;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final (colours, icon, label) = switch (change) {
      DkChange.added => (t.compare.added, DkIcons.add, l.compare_added),
      DkChange.removed => (
        t.compare.removed,
        DkIcons.remove,
        l.compare_removed,
      ),
      DkChange.changed => (t.compare.changed, DkIcons.dot, l.compare_changed),
    };
    return DkTappable(
      onTap: onTap,
      radius: t.radius.m,
      builder: (context, pressed) => Semantics(
        button: true,
        label: '$label: $excerpt',
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: EdgeInsets.symmetric(
            horizontal: t.space.l,
            vertical: t.space.s,
          ),
          color: pressed ? t.state.pressed : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: t.space.m,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: t.space.s,
                  vertical: t.space.xxs,
                ),
                decoration: BoxDecoration(
                  color: colours.background,
                  borderRadius: BorderRadius.circular(t.radius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: t.space.xxs,
                  children: [
                    // Filled: the changed dot is a solid dot.
                    DkIcon(
                      icon,
                      size: DkIconSize.s,
                      color: colours.text,
                      filled: true,
                    ),
                    Text(
                      label,
                      style: t.text.caption.copyWith(
                        color: colours.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.text.bodyM.copyWith(
                    color: t.color.textPrimary,
                    decoration: change == DkChange.removed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              DkPageChip(page: page, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}
