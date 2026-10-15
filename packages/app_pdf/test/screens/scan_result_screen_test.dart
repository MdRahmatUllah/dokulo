import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/screens/s2_review/scan_result_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> calls;

  Future<void> pump(
    WidgetTester tester, {
    DkTokens? tokens,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    calls = [];
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dokuloTheme(tokens ?? DkTokens.light),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScanResultScreen(
          scan: (
            name: 'Scan 2026-10-07 14.32.pdf',
            pages: 6,
            bytes: 2100000,
            textPages: 6,
            place: 'Files › Apartment',
          ),
          onClose: () => calls.add('close'),
          onOpen: () => calls.add('open'),
          onTool: (id) => calls.add(id),
          onShare: () => calls.add('share'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the result, the name, Next chips to the tools, Open', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Scan saved'), findsOneWidget);
    expect(find.text('6 pages'), findsOneWidget);
    expect(find.textContaining('Text found on 6 of 6 pages'), findsOneWidget);
    expect(find.text('Scan 2026-10-07 14.32.pdf'), findsOneWidget);
    await tester.tap(find.text('Compress PDF'));
    await tester.tap(find.text('Share'));
    await tester.tap(find.text('Open'));
    expect(calls, ['compress', 'share', 'open']);
  });

  for (final (name, tokens, locale) in [
    ('light', DkTokens.light, const Locale('en')),
    ('dark', DkTokens.dark, const Locale('en')),
    ('de', DkTokens.light, const Locale('de')),
  ]) {
    testWidgets('golden: scan result ($name)', (tester) async {
      await pump(tester, tokens: tokens, locale: locale);
      await expectLater(
        find.byType(ScanResultScreen),
        matchesGoldenFile('goldens/scan_result_$name.png'),
      );
    });
  }
}
