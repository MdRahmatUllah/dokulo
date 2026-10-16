import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/legal/third_party.dart';
import 'package:app_pdf/screens/settings/licences_settings_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// M3 · Open-source licences (DK-0577; me-licences, me-licence).
void main() {
  const items = <LicenceItem>[
    (name: 'Bergamot translator', licence: 'MPL-2.0', texts: ['MPL text']),
    (name: 'Caveat', licence: 'OFL-1.1', texts: ['OFL text']),
    (name: 'go_router', licence: '', texts: ['BSD text']),
    (
      name: 'Material Symbols',
      licence: 'Apache-2.0',
      texts: ['Apache License\nVersion 2.0, January 2004'],
    ),
    (name: 'PDFium', licence: 'BSD-3-Clause', texts: ['BSD text']),
  ];

  Future<void> pump(
    WidgetTester tester, {
    DkTokens? tokens,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [licencesProvider.overrideWith((ref) async => items)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dokuloTheme(tokens ?? DkTokens.light),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LicencesSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('every component with its licence; a package without an id '
      'shows only its name', (tester) async {
    await pump(tester);
    expect(find.text('Material Symbols'), findsOneWidget);
    expect(find.text('Apache-2.0'), findsOneWidget);
    expect(find.text('go_router'), findsOneWidget);
    expect(find.text('BSD-3-Clause'), findsOneWidget);
  });

  testWidgets('search narrows by name or licence', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'ofl');
    await tester.pumpAndSettle();
    expect(find.text('Caveat'), findsOneWidget);
    expect(find.text('PDFium'), findsNothing);
  });

  testWidgets('a row opens the full text', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Material Symbols'));
    await tester.pumpAndSettle();
    expect(find.text('Licence'), findsOneWidget);
    expect(find.text('Material Symbols · Apache-2.0'), findsOneWidget);
    expect(find.textContaining('Version 2.0, January 2004'), findsOneWidget);
  });

  test('the real list: Flutter registry and the register, sorted', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final all = await licences();
    final names = [for (final i in all) i.name.toLowerCase()];
    expect(names, orderedEquals([...names]..sort()));
    expect(names, contains('pdfium'));
  });

  for (final (name, tokens, locale) in [
    ('light', DkTokens.light, const Locale('en')),
    ('dark', DkTokens.dark, const Locale('en')),
    ('de', DkTokens.light, const Locale('de')),
  ]) {
    testWidgets('golden: licences ($name)', (tester) async {
      await pump(tester, tokens: tokens, locale: locale);
      await expectLater(
        find.byType(LicencesSettingsScreen),
        matchesGoldenFile('goldens/licences_$name.png'),
      );
    });

    testWidgets('golden: one licence ($name)', (tester) async {
      await pump(tester, tokens: tokens, locale: locale);
      await tester.tap(find.text('Material Symbols'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Navigator),
        matchesGoldenFile('goldens/licence_$name.png'),
      );
    });
  }
}
