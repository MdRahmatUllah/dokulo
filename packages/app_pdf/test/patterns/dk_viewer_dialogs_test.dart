import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/patterns/dk_viewer_dialogs.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Object? answer;

  Future<void> open(
    WidgetTester tester,
    Future<Object?> Function(BuildContext) show, {
    DkTokens? tokens,
  }) async {
    answer = 'none';
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dokuloTheme(tokens ?? DkTokens.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => answer = await show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Go to page (DK-0307): "1–12", a page outside is refused, Go '
      'answers the page', (tester) async {
    await open(tester, (c) => showGoToPage(c, pageCount: 12, current: 1));
    expect(find.text('Go to page'), findsOneWidget);
    expect(find.text('1–12'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '40');
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a page from 1 to 12.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '7');
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(answer, 7);
  });

  testWidgets('Go to page: Cancel answers nothing', (tester) async {
    await open(tester, (c) => showGoToPage(c, pageCount: 12));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(answer, isNull);
  });

  testWidgets('External link (DK-0308): "Open example.com in your browser?"', (
    tester,
  ) async {
    await open(
      tester,
      (c) => confirmOpenLink(c, Uri.parse('https://example.com/hausordnung')),
    );
    expect(find.text('Open example.com in your browser?'), findsOneWidget);
    expect(
      find.text('This is the only step that leaves Dokulo.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });

  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('golden: viewer_goto_$theme', (tester) async {
      await open(
        tester,
        (c) => showGoToPage(c, pageCount: 12, current: 7),
        tokens: tokens,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/viewer_goto_$theme.png'),
      );
    });

    testWidgets('golden: viewer_link_$theme', (tester) async {
      await open(
        tester,
        (c) => confirmOpenLink(c, Uri.parse('https://example.com')),
        tokens: tokens,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/viewer_link_$theme.png'),
      );
    });
  }
}
