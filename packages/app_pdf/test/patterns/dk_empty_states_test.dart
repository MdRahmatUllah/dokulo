import 'package:app_pdf/catalogue/empty_states_gallery.dart';
import 'package:app_pdf/components/dk_button.dart';
import 'package:app_pdf/components/dk_empty_state.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/patterns/dk_empty_states.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Widget child, {
  DkTokens? tokens,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final lang in ['en', 'de']) {
      testWidgets('golden: empty_states_${theme}_$lang', (tester) async {
        tester.view.physicalSize = const Size(393, 2200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(const EmptyStatesGallery(), tokens: tokens, locale: Locale(lang)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/empty_states_${theme}_$lang.png'),
        );
      });
    }
  }

  testWidgets('the copy and buttons of §26.1, EN and DE (DK-0601…DK-0605)', (
    tester,
  ) async {
    var scans = 0, opens = 0, moves = 0;
    Widget all(BuildContext context) => Column(
      children: [
        DkEmptyStates.homeRecents(context, onScan: () => scans++),
        DkEmptyStates.filesRoot(
          context,
          onScan: () => scans++,
          onOpenFile: () => opens++,
        ),
        DkEmptyStates.folder(context, onMove: () => moves++),
        DkEmptyStates.search(context, query: 'Kaution'),
        DkEmptyStates.trash(context),
      ],
    );
    tester.view.physicalSize = const Size(393, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(Builder(builder: all)));
    for (final text in [
      'Your scans and PDFs will appear here',
      'No files yet',
      'This folder is empty',
      'Move files here or save tool results here.',
      'Nothing found for “Kaution”',
      'Try another word or check the spelling.',
      'Nothing here',
      'Deleted files stay here for 30 days.',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(
      find.text('Scan a document or open a PDF to get started.'),
      findsNWidgets(2),
    );
    await tester.tap(find.text('Scan a document').first);
    await tester.tap(find.text('Open a file'));
    await tester.tap(find.text('Move files here'));
    expect((scans, opens, moves), (1, 1, 1));
    // Search and Trash have no button.
    final buttons = tester.widgetList<DkEmptyState>(find.byType(DkEmptyState));
    expect(buttons.map((e) => e.action == null).toList(), [
      false,
      false,
      false,
      true,
      true,
    ]);
    expect(
      tester
          .widgetList<DkEmptyState>(find.byType(DkEmptyState))
          .elementAt(2)
          .actionVariant,
      DkButtonVariant.secondary,
    );

    await tester.pumpWidget(
      app(Builder(builder: all), locale: const Locale('de')),
    );
    for (final text in [
      'Deine Scans und PDFs erscheinen hier',
      'Noch keine Dateien',
      'Dieser Ordner ist leer',
      'Nichts gefunden für „Kaution“',
      'Hier ist nichts',
      'Dokument scannen',
      'Datei öffnen',
      'Dateien hierher verschieben',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
  });
}
