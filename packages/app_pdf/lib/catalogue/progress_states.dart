import 'package:flutter/material.dart';

import '../components/dk_icon.dart';
import '../components/dk_progress_sheet.dart';
import '../components/dk_sheet.dart';
import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';

void _none() {}

/// DkProgressSheet (DK-0194) on a sheet's surface: running with the page
/// and the time left; just started, no estimate yet; failed. Then a button
/// that opens it in a real small sheet.
class ProgressSheetStates extends StatelessWidget {
  const ProgressSheetStates({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final compress = DkIcons.tool('compress');
    Widget sheet(Widget child) => DecoratedBox(
      decoration: t.surfaceAt(
        DkLevel.overlay,
        radius: BorderRadius.vertical(top: Radius.circular(t.radius.sheet)),
      ),
      child: Padding(padding: EdgeInsets.all(t.space.l), child: child),
    );
    return ColoredBox(
      color: t.color.scrim,
      child: Padding(
        padding: EdgeInsets.only(top: t.space.xl),
        child: Column(
          spacing: t.space.xl,
          children: [
            sheet(
              DkProgressSheet(
                toolIcon: compress,
                title: 'Compressing Mietvertrag.pdf',
                progress: 0.45,
                page: 18,
                pageCount: 40,
                timeLeft: '20 s',
                onCancel: _none,
                onKeepWorking: _none,
              ),
            ),
            sheet(
              DkProgressSheet(
                toolIcon: compress,
                title: 'Compressing Mietvertrag.pdf',
                progress: 0.02,
                onCancel: _none,
                onKeepWorking: _none,
              ),
            ),
            sheet(
              DkProgressSheet(
                toolIcon: compress,
                title: 'Compressing Mietvertrag.pdf',
                progress: 0.6,
                onCancel: _none,
                onKeepWorking: _none,
                error: const DkProgressError(
                  title: "Couldn't compress this file",
                  body: 'The file may be damaged. Your original is unchanged.',
                  action: 'Try again',
                  onAction: _none,
                ),
              ),
            ),
            Builder(
              builder: (context) => OutlinedButton(
                onPressed: () => showDkSheet<void>(
                  context,
                  body: DkProgressSheet(
                    toolIcon: compress,
                    title: 'Compressing Mietvertrag.pdf',
                    progress: 0.45,
                    page: 18,
                    pageCount: 40,
                    timeLeft: '20 s',
                    onCancel: () => Navigator.pop(context),
                    onKeepWorking: () => Navigator.pop(context),
                  ),
                ),
                child: const Text('Open as a sheet'),
              ),
            ),
            SizedBox(height: t.space.l),
          ],
        ),
      ),
    );
  }
}
