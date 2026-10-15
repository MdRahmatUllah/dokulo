import 'package:app_pdf/components/dk_pdf_search.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_search.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// "4 of 17" without a document: the bar only reads these.
class _Search extends DkPdfSearch {
  _Search(this._count, this._current) {
    search('Mieter');
  }

  final int _count;
  final int? _current;

  @override
  int get count => _count;
  @override
  int? get current => _current;
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    DkPdfSearch search, {
    DkTokens? tokens,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(393, 57);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(search.dispose);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dokuloTheme(tokens ?? DkTokens.light),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ViewerSearchBar(search: search, onDone: () {}),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the counter reads "4 of 17"; no matches, no arrows', (
    tester,
  ) async {
    await pump(tester, _Search(17, 3));
    expect(find.text('4 of 17'), findsOneWidget);
    await pump(tester, _Search(0, null));
    expect(find.text('0 results'), findsOneWidget);
  });

  // viewer-search (light, dark, deutsch).
  for (final (name, tokens, locale) in [
    ('light', DkTokens.light, const Locale('en')),
    ('dark', DkTokens.dark, const Locale('en')),
    ('de', DkTokens.light, const Locale('de')),
  ]) {
    testWidgets('golden: search bar ($name)', (tester) async {
      await pump(tester, _Search(17, 3), tokens: tokens, locale: locale);
      await expectLater(
        find.byType(ViewerSearchBar),
        matchesGoldenFile('goldens/viewer_search_$name.png'),
      );
    });
  }
}
