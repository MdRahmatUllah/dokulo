import 'package:app_pdf/components/dk_button.dart';
import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/components/dk_toast.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/patterns/dk_confirmations.dart';
import 'package:app_pdf/patterns/dk_undo.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A screen with one button that runs [run] with its context.
Widget app(
  Future<void> Function(BuildContext) run, {
  Locale locale = const Locale('en'),
}) => MaterialApp(
  theme: dokuloTheme(DkTokens.light),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => run(context),
          child: const Text('go'),
        ),
      ),
    ),
  ),
);

DkButtonVariant variantOf(WidgetTester tester, String label) => tester
    .widget<DkButton>(
      find.ancestor(of: find.text(label), matching: find.byType(DkButton)),
    )
    .variant;

void main() {
  group('confirmDk (DK-0225, UI spec §12.4)', () {
    // Each kind: its title, body, way out and action, and whether the
    // action is the danger button.
    for (final (kind, title, body, cancel, action, danger) in [
      (
        DkConfirmation.deleteForever,
        'Delete 3 files for good?',
        "This can't be undone.",
        'Cancel',
        'Delete for good',
        true,
      ),
      (
        DkConfirmation.emptyTrash,
        'Delete 3 files for good?',
        "This can't be undone.",
        'Cancel',
        'Delete for good',
        true,
      ),
      (
        DkConfirmation.applyRedaction,
        'Black out for good?',
        "What you blacked out is removed from the file and can't be "
            'recovered.',
        'Cancel',
        'Black out',
        true,
      ),
      (
        DkConfirmation.replaceOriginal,
        'Replace the original file?',
        'The original will be kept in Versions for 30 days.',
        'Cancel',
        'Replace',
        false,
      ),
      (
        DkConfirmation.discardScan,
        'Discard this scan?',
        'All pages of this scan will be deleted.',
        'Keep',
        'Discard',
        true,
      ),
      (
        DkConfirmation.discardEdits,
        'Discard your changes?',
        'Your edits since opening edit mode will be lost.',
        'Keep editing',
        'Discard',
        true,
      ),
      (
        DkConfirmation.cancelJob,
        'Stop this job?',
        'Your original file stays unchanged.',
        'Keep going',
        'Stop',
        false,
      ),
      (
        DkConfirmation.removeSignature,
        'Remove this signature?',
        "It's deleted from this phone.",
        'Cancel',
        'Remove',
        true,
      ),
    ]) {
      testWidgets('${kind.name}: "$title", $cancel / $action', (tester) async {
        final answers = <bool>[];
        await tester.pumpWidget(
          app((c) async => answers.add(await confirmDk(c, kind, count: 3))),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        expect(find.text(body), findsOneWidget);
        expect(
          variantOf(tester, action),
          danger ? DkButtonVariant.destructive : DkButtonVariant.primary,
        );
        await tester.tap(find.text(cancel));
        await tester.pumpAndSettle();
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(answers, [false, true]);
      });
    }

    testWidgets('"Confirm empty" has the danger icon; one file reads as one', (
      tester,
    ) async {
      await tester.pumpWidget(
        app((c) => confirmDk(c, DkConfirmation.emptyTrash)),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this file for good?'), findsOneWidget);
      expect(find.byIcon(DkIcons.deleteForever), findsOneWidget);
    });

    testWidgets('a tool names its own job; German', (tester) async {
      await tester.pumpWidget(
        app(
          (c) => confirmDk(
            c,
            DkConfirmation.cancelJob,
            title: 'Komprimieren stoppen?',
          ),
          locale: const Locale('de'),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Komprimieren stoppen?'), findsOneWidget);
      expect(
        find.text('Deine Originaldatei bleibt unverändert.'),
        findsOneWidget,
      );
      expect(find.text('Weitermachen'), findsOneWidget);
      expect(find.text('Stoppen'), findsOneWidget);
    });
  });

  group('showDkUndo (DK-0226, UI spec §12.6)', () {
    testWidgets('Undo runs once and reports it', (tester) async {
      var undone = 0;
      final results = <bool>[];
      await tester.pumpWidget(
        app(
          (c) async => results.add(
            await showDkUndo(
              c,
              DkUndo.deleteToTrash,
              'Moved to Recently deleted',
              onUndo: () => undone++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Moved to Recently deleted'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(undone, 1);
      expect(results, [true]);
    });

    testWidgets('it goes after 4 s without Undo; Replace original after 10', (
      tester,
    ) async {
      expect(DkUndo.move.duration, DkToastDuration.regular);
      expect(DkUndo.replaceOriginal.duration, const Duration(seconds: 10));
      var undone = 0;
      final results = <bool>[];
      await tester.pumpWidget(
        app(
          (c) async => results.add(
            await showDkUndo(
              c,
              DkUndo.replaceOriginal,
              'Replaced',
              onUndo: () => undone++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Replaced'), findsOneWidget); // still there at 6 s
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Replaced'), findsNothing);
      expect(undone, 0);
      expect(results, [false]);
    });
  });
}
