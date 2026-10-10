// Visual QA (DK-09xx): shows catalogue entries one at a time on a device,
// with the app's real fonts, in Light and Dark, so the host can screenshot
// each and compare it with its frame in dokulo-design/:
//   python tools/device_checks/catalogue_shots.py emulator-5556 OUT "DkPinPad;DkDropdown"
// The entries come from --dart-define=QA_ENTRIES=name1;name2 (all if empty;
// ';' between them, as some names hold a comma).
import 'package:app_pdf/catalogue/catalogue.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const wanted = String.fromEnvironment('QA_ENTRIES');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('catalogue entries, one at a time', (tester) async {
    final names = wanted.isEmpty ? null : wanted.split(';').toSet();
    for (final entry in catalogue) {
      if (names != null && !names.contains(entry.name)) continue;
      for (final (theme, tokens) in [
        ('light', DkTokens.light),
        ('dark', DkTokens.dark),
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dokuloTheme(tokens),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: entry.states,
                  ),
                ),
              ),
            ),
          ),
        );
        // Two pumps: MaterialApp's theme blends in from the last entry's
        // theme, and an implicit animation (DkIconButton's fill) only
        // starts from that blend once it has finished.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        debugPrint('DEVICE | QA | ${entry.name} | $theme');
        // The host takes its screenshot now.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 4)),
        );
      }
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
