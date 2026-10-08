import 'package:app_pdf/l10n/app_language.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/l10n/formats.dart';
import 'package:app_pdf/main.dart';
import 'package:app_pdf/providers/language_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  testWidgets('the app follows the system language by default', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const ProviderScope(child: DokuloApp()));
    await tester.pumpAndSettle(); // past the launch screen (DK-0073)
    expect(find.text('Start'), findsOneWidget); // the Home tab
  });

  testWidgets('changing the language applies at once, without a restart', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const ProviderScope(child: DokuloApp()));
    await tester.pumpAndSettle(); // past the launch screen (DK-0073)
    final language = ProviderScope.containerOf(
      tester.element(find.byType(DokuloApp)),
    ).read(appLanguageSettingProvider.notifier);
    expect(find.text('Home'), findsOneWidget);

    language.select(AppLanguage.deutsch);
    await tester.pump();
    expect(find.text('Start'), findsOneWidget); // the Home tab

    language.select(AppLanguage.system);
    await tester.pump();
    expect(find.text('Home'), findsOneWidget);
  });

  test('plurals and placeholders', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final de = await AppLocalizations.delegate.load(const Locale('de'));
    expect(en.meta_pages(1), '1 page');
    expect(en.meta_pages(12), '12 pages');
    expect(de.meta_files(1), '1 Datei');
    expect(de.meta_files(3), '3 Dateien');
    expect(de.toast_saved_to('Rechnungen'), 'Gespeichert in Rechnungen');
    expect(de.progress_page(2, 9), 'Seite 2 von 9');
  });

  test('sizes and dates follow the locale', () async {
    expect(formatBytes(1900000, 'en'), '1.9${unitSpace}MB');
    expect(formatBytes(1900000, 'de'), '1,9${unitSpace}MB');
    expect(formatBytes(32000000, 'de'), '32${unitSpace}MB');
    expect(formatBytes(1800000000, 'en'), '1.8${unitSpace}GB');
    expect(formatBytes(9960000, 'en'), '10${unitSpace}MB');
    expect(formatBytes(512, 'de'), '512${unitSpace}B');
    expect(formatBytes(999960, 'en'), '1${unitSpace}MB');

    await initializeDateFormatting('de');
    await initializeDateFormatting('en');
    final day = DateTime(2026, 10, 7);
    expect(formatDate(day, 'en'), '7 Oct 2026');
    expect(formatDate(day, 'de'), '7. Okt. 2026');
  });
}
