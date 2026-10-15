import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/l10n/app_language.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/language_providers.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/screens/settings/language_settings_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// M3 · Language (DK-0575).
void main() {
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    DkTokens? tokens,
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
        // The app root's locale, as main.dart sets it.
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dokuloTheme(tokens ?? DkTokens.light),
            locale: ref.watch(appLanguageSettingProvider).locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LanguageSettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('System by default; Deutsch applies at once and is kept', (
    tester,
  ) async {
    await pump(tester);
    expect(container.read(appLanguageSettingProvider), AppLanguage.system);
    expect(find.byIcon(DkIcons.check), findsOneWidget);
    expect(
      tester.getSemantics(find.widgetWithText(MergeSemantics, 'System').first),
      isSemantics(
        label: 'System',
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    expect(find.text('Sprache'), findsOneWidget); // no restart
    expect(find.text('Englisch'), findsOneWidget);
    expect(container.read(prefsProvider).value?[appLanguageKey], 'deutsch');
  });

  testWidgets('a kept choice is read back after a restart', (tester) async {
    await pump(tester, prefs: {appLanguageKey: 'english'});
    expect(container.read(appLanguageSettingProvider), AppLanguage.english);
    expect(
      tester.getSemantics(find.widgetWithText(MergeSemantics, 'English').first),
      isSemantics(
        label: 'English',
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
  });

  for (final (name, tokens, prefs) in [
    ('light', DkTokens.light, const <String, Object?>{}),
    ('dark', DkTokens.dark, const <String, Object?>{}),
    ('de', DkTokens.light, const {appLanguageKey: 'deutsch'}),
  ]) {
    testWidgets('golden: language ($name)', (tester) async {
      await pump(tester, tokens: tokens, prefs: prefs);
      await expectLater(
        find.byType(LanguageSettingsScreen),
        matchesGoldenFile('goldens/language_$name.png'),
      );
    });
  }
}
