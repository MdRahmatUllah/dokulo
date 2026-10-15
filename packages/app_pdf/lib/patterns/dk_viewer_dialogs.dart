import 'package:flutter/material.dart';

import '../components/dk_button.dart';
import '../components/dk_confirm_dialog.dart';
import '../components/dk_text_field.dart';
import '../components/motion/dk_transition_motion.dart';
import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';

/// V1 Go to page (UI spec §17.1; DK-0307): a small dialog with a number
/// field and the helper "1–32"; Go answers the page (1-based), Cancel null.
/// A number outside the file is refused under the field.
Future<int?> showGoToPage(
  BuildContext context, {
  required int pageCount,
  int? current,
}) => Navigator.of(context).push<int>(
  DkDialogRoute.of(
    context,
    builder: (context) => _GoToPage(pageCount: pageCount, current: current),
  ),
);

class _GoToPage extends StatefulWidget {
  const _GoToPage({required this.pageCount, this.current});

  final int pageCount;
  final int? current;

  @override
  State<_GoToPage> createState() => _GoToPageState();
}

class _GoToPageState extends State<_GoToPage> {
  late final _page = TextEditingController(text: '${widget.current ?? ''}');
  var _invalid = false;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _go() {
    final n = int.tryParse(_page.text.trim());
    if (n == null || n < 1 || n > widget.pageCount) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final width = MediaQuery.sizeOf(context).width;
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: (width - 2 * t.space.xl).clamp(0, 320),
          padding: EdgeInsets.all(t.space.xl),
          decoration: BoxDecoration(
            color: t.color.surfaceRaised,
            borderRadius: BorderRadius.circular(t.radius.l),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.viewer_goto_title,
                style: t.text.titleM.copyWith(color: t.color.textPrimary),
              ),
              SizedBox(height: t.space.l),
              DkTextField(
                controller: _page,
                autofocus: true,
                clearable: false,
                keyboardType: TextInputType.number,
                helper: l.viewer_goto_range(widget.pageCount),
                error: _invalid
                    ? l.viewer_goto_invalid(widget.pageCount)
                    : null,
                onChanged: (_) {
                  if (_invalid) setState(() => _invalid = false);
                },
                onSubmitted: (_) => _go(),
              ),
              SizedBox(height: t.space.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: t.space.s,
                children: [
                  DkButton(
                    label: l.common_cancel,
                    variant: DkButtonVariant.tertiary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  DkButton(label: l.viewer_goto_action, onPressed: _go),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// V1 External link (UI spec §17.1; DK-0308): "Open example.com in your
/// browser?", "This is the only step that leaves Dokulo.", Cancel / Open.
Future<bool> confirmOpenLink(BuildContext context, Uri url) {
  final l = AppLocalizations.of(context);
  return showDkConfirm(
    context,
    title: l.viewer_link_title(url.host.isEmpty ? url.toString() : url.host),
    body: l.viewer_link_body,
    action: l.viewer_link_open,
  );
}
