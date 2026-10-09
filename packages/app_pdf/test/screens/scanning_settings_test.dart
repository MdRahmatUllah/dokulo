import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/screens/m3_settings/scanning_settings_screen.dart';
import 'package:app_pdf/screens/s1_scanner/scanner_settings.dart';
import 'package:app_pdf/screens/s2_review/save_sheet.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late MemoryPrefsStore prefs;

  ScannerPrefs read() => container.read(scannerSettingsProvider);

  Future<void> pump(
    WidgetTester tester, {
    DkTokens? tokens,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        scannerPrefsStoreProvider.overrideWithValue(prefs = MemoryPrefsStore()),
        scanClockProvider.overrideWithValue(
          () => DateTime(2026, 10, 7, 14, 32),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dokuloTheme(tokens ?? DkTokens.light),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ScanningSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('scanName fills the pattern', () {
    final now = DateTime(2026, 10, 7, 14, 32);
    expect(scanName(now), 'Scan 2026-10-07 14.32');
    expect(
      scanName(now, pattern: 'Receipt {number} {date}', number: 3),
      'Receipt 3 2026-10-07',
    );
  });

  testWidgets('switches and the page size write the defaults', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Auto-capture'));
    await tester.pumpAndSettle();
    expect(read().autoCapture, isTrue);
    await tester.tap(find.text('Page size'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A4'));
    await tester.pumpAndSettle();
    expect(read().pageSize, ScanPageSize.a4);
    expect(prefs.json, contains('"pageSize":"a4"'));
  });

  testWidgets('Default filter: a page of the five, with what each is for', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Default filter'));
    await tester.pumpAndSettle();
    expect(find.text('Crisp text, smallest files'), findsOneWidget);
    await tester.tap(find.text('Black & white'));
    await tester.pumpAndSettle();
    expect(read().filter, ScanFilterChoice.blackWhite);
  });

  testWidgets('File name: insert a token, see the preview, save', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('File name'));
    await tester.pumpAndSettle();
    expect(find.text('Scan 2026-10-07 14.32.pdf'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'Receipt ');
    await tester.tap(find.text('number'));
    await tester.pumpAndSettle();
    expect(find.text('Receipt 1.pdf'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(read().namePattern, 'Receipt {number}');
  });

  testWidgets('Text recognition language', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Text recognition language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    expect(read().ocrLanguage, ScanOcrLanguage.german);
  });

  for (final (name, tokens, locale) in [
    ('light', DkTokens.light, const Locale('en')),
    ('dark', DkTokens.dark, const Locale('en')),
    ('de', DkTokens.light, const Locale('de')),
  ]) {
    testWidgets('golden: scanning settings ($name)', (tester) async {
      await pump(tester, tokens: tokens, locale: locale);
      await expectLater(
        find.byType(ScanningSettingsScreen),
        matchesGoldenFile('goldens/scanning_settings_$name.png'),
      );
    });
  }
}
