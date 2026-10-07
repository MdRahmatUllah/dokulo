import 'package:app_pdf/catalogue/catalogue.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('every catalogue entry opens from /dev/components', (
    tester,
  ) async {
    final router = buildRouter(initialLocation: '/dev/components');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: dokuloTheme(DkTokens.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    for (final entry in catalogue) {
      await tester.tap(find.text(entry.name));
      await tester.pumpAndSettle();
      // Light, then Dark.
      expect(find.byWidget(entry.states), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      router.pop();
      await tester.pumpAndSettle();
    }
  });
}
