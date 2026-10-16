import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/providers/theme_providers.dart';
import 'package:app_pdf/screens/settings/appearance_settings_screen.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_screen.dart'
    show viewerNightKey;
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// M3 · Appearance (DK-0574).
void main() {
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    Map<String, Object?> prefs = const {},
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [prefsProvider.overrideWith(() => Prefs.memory(prefs))],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // The app root's theme, as main.dart sets it.
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dokuloTheme(DkTokens.light),
            darkTheme: dokuloTheme(DkTokens.dark),
            themeMode: ref.watch(appThemeModeProvider),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AppearanceSettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('System by default; Dark applies at once and is kept', (
    tester,
  ) async {
    await pump(tester);
    expect(container.read(appThemeModeProvider), ThemeMode.system);
    expect(
      tester.getSemantics(find.bySemanticsLabel('System')),
      isSemantics(
        label: 'System',
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(container.read(appThemeModeProvider), ThemeMode.dark);
    expect(container.read(prefsProvider).value?[appThemeKey], 'dark');
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, DkColors.dark.background);
  });

  testWidgets('Viewer night mode: off by default, the row switches it', (
    tester,
  ) async {
    await pump(tester);
    expect(container.read(prefsProvider).value?[viewerNightKey], isNull);
    await tester.tap(find.text('Viewer night mode'));
    await tester.pumpAndSettle();
    expect(container.read(prefsProvider).value?[viewerNightKey], isTrue);
  });

  testWidgets('a kept theme is read back after a restart', (tester) async {
    await pump(tester, prefs: {appThemeKey: 'light'});
    expect(container.read(appThemeModeProvider), ThemeMode.light);
  });

  for (final (name, locale, prefs) in [
    (
      'light',
      const Locale('en'),
      const <String, Object?>{appThemeKey: 'light'},
    ),
    ('dark', const Locale('en'), const <String, Object?>{appThemeKey: 'dark'}),
    ('de', const Locale('de'), const <String, Object?>{appThemeKey: 'light'}),
  ]) {
    testWidgets('golden: appearance ($name)', (tester) async {
      await pump(tester, locale: locale, prefs: prefs);
      await expectLater(
        find.byType(AppearanceSettingsScreen),
        matchesGoldenFile('goldens/appearance_$name.png'),
      );
    });
  }
}
