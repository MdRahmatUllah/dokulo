import 'package:flutter/material.dart';

import '../../components/dk_button.dart';
import '../../components/dk_pdf_search.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_icon_button.dart';
import '../../components/dk_number_text.dart';
import '../../components/dk_text_field.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dk_tokens.dart';

/// The search bar in place of V1's top bar (UI spec §17.1): the field with
/// "2 of 17" / "0 results" inside, previous and next, Done.
class ViewerSearchBar extends StatefulWidget {
  const ViewerSearchBar({
    super.key,
    required this.search,
    required this.onDone,
  });

  final DkPdfSearch search;
  final VoidCallback onDone;

  @override
  State<ViewerSearchBar> createState() => _ViewerSearchBarState();
}

class _ViewerSearchBarState extends State<ViewerSearchBar> {
  late final _field = TextEditingController(text: widget.search.query);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.search,
      builder: (context, _) {
        final s = widget.search;
        final counter = s.query.isEmpty
            ? null
            : s.count == 0
            ? (s.searching ? null : l.viewer_search_none)
            : l.viewer_search_of((s.current ?? 0) + 1, s.count);
        return Container(
          color: t.color.surface,
          padding: EdgeInsets.fromLTRB(
            t.space.l,
            t.space.s,
            t.space.s,
            t.space.s,
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              spacing: t.space.xs,
              children: [
                Expanded(
                  child: DkTextField(
                    controller: _field,
                    autofocus: s.query.isEmpty,
                    textInputAction: TextInputAction.search,
                    leading: DkIcon(
                      DkIcons.search,
                      color: t.color.iconSecondary,
                    ),
                    trailing: counter == null
                        ? null
                        : Padding(
                            padding: EdgeInsets.only(right: t.space.m),
                            child: DkNumberText(
                              counter,
                              style: t.text.caption.copyWith(
                                color: t.color.textSecondary,
                              ),
                            ),
                          ),
                    clearable: false,
                    onChanged: s.search,
                    onSubmitted: (_) => s.next(),
                  ),
                ),
                DkIconButton(
                  icon: DkIcons.expandLess,
                  tooltip: l.viewer_search_previous,
                  onPressed: s.count > 0 ? s.previous : null,
                ),
                DkIconButton(
                  icon: DkIcons.expandMore,
                  tooltip: l.viewer_search_next,
                  onPressed: s.count > 0 ? s.next : null,
                ),
                DkButton(
                  label: l.common_done,
                  variant: DkButtonVariant.tertiary,
                  size: DkButtonSize.compact,
                  onPressed: widget.onDone,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
