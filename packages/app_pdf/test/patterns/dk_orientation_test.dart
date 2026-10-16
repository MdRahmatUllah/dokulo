import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/patterns/dk_orientation.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phone orientation locks (DK-0656; UI spec §30).
void main() {
  const portrait = [DeviceOrientation.portraitUp];

  test('phones: portrait but on the Viewer, Scanner, Compare, Translate', () {
    for (final location in [
      Routes.home,
      Routes.files,
      Routes.me,
      '/tool/compress',
      '/tool/compare/result',
    ]) {
      expect(
        orientationsFor(location, phone: true),
        location == '/tool/compare/result' ? isEmpty : portrait,
        reason: location,
      );
    }
    for (final location in [
      '/viewer/12?page=3',
      Routes.scan,
      Routes.scanReview,
      '/tool/compare',
      '/tool/translate?file=a.pdf',
    ]) {
      expect(orientationsFor(location, phone: true), isEmpty, reason: location);
    }
    // A path that only starts like one doesn't turn.
    expect(orientationsFor('/scanner-help', phone: true), portrait);
  });

  test('tablets turn everywhere', () {
    expect(orientationsFor(Routes.home, phone: false), isEmpty);
  });

  testWidgets('the shell applies the rule as the route changes', (
    tester,
  ) async {
    final calls = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          calls.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = DokuloDatabase.memory();
    addTearDown(db.close);
    final router = buildRouter(initialLocation: Routes.me);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRouterProvider.overrideWithValue(router),
          appDatabaseProvider.overrideWithValue(db),
          prefsProvider.overrideWith(Prefs.memory),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: dokuloTheme(DkTokens.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => DkOrientation(child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls.last, ['DeviceOrientation.portraitUp']);
    expect(DkOrientation.current, portrait);

    router.go(Routes.scan);
    await tester.pumpAndSettle();
    expect(calls.last, isEmpty);
  });
}
