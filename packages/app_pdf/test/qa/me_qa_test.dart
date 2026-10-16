import 'dart:io';

import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/locked_providers.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/screens/me/me_screen.dart';
import 'package:app_pdf/screens/settings/language_settings_screen.dart';
import 'package:app_pdf/screens/settings/security_settings_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../routes/routes_test.dart' show pumpAt;
import '../screens/files_screen_test.dart' show FilesFixture, pumpFiles, settle;
import '../screens/locked_folder_screen_test.dart' show LockedSetup;

// Visual QA (DK-0937, DK-0941, DK-0942, DK-0944): the 22-me-settings frames
// mepro, files, security and language, rendered by the real M1 and M3 pages at 393 × 852.
// The goldens sit next to the frames' screenshots in docs/qa/me/; the
// findings are in docs/qa/me.md.
void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    Future<void> shot(WidgetTester tester, String frame) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/qa_me_${frame}_$theme.png'),
    );

    testWidgets('me-mepro, $theme', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpAt(
        tester,
        Routes.me,
        tokens: tokens,
        overrides: [isProProvider.overrideWithValue(true)],
      );
      await shot(tester, 'mepro');
    });

    testWidgets('me-files, $theme', (tester) async {
      final f = FilesFixture();
      await tester.runAsync(() async {
        await f.setUp();
        File('${f.root.path}/Dokulo/a.pdf')
          ..createSync(recursive: true)
          ..writeAsBytesSync(List.filled(3000, 1));
      });
      addTearDown(() => tester.runAsync(f.tearDown));
      await pumpFiles(
        tester,
        f,
        tokens: tokens,
        location: Routes.settings('files'),
      );
      for (var i = 0; i < 4; i++) {
        await settle(tester);
      }
      await shot(tester, 'files');
    });

    testWidgets('me-security (App lock on, Face ID on), $theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final setup = LockedSetup();
      await setup.vault.setPin('482915');
      await setup.vault.enableBiometrics('test');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lockedVaultProvider.overrideWithValue(setup.vault),
            biometricKindProvider.overrideWith(
              (ref) async => BiometricKind.faceId,
            ),
            prefsProvider.overrideWith(
              () => Prefs.memory({'security.appLock': true}),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dokuloTheme(tokens),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SecuritySettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await shot(tester, 'security');
    });
  }

  // DK-0944: 22-me-settings/me-language (System selected), light, dark, DE.
  for (final (theme, tokens, locale) in [
    ('light', DkTokens.light, const Locale('en')),
    ('dark', DkTokens.dark, const Locale('en')),
    ('deutsch', DkTokens.light, const Locale('de')),
  ]) {
    testWidgets('me-language, $theme', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsProvider.overrideWith(() => Prefs.memory({}))],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dokuloTheme(tokens),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LanguageSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/qa_me_language_$theme.png'),
      );
    });
  }
}
