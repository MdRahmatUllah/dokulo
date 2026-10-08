import 'package:app_pdf/catalogue/catalogue.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('every catalogue entry opens from /dev/catalogue', (
    tester,
  ) async {
    final router = buildRouter(initialLocation: '/dev/catalogue');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      // Some components read providers (DkChip plays the haptic).
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          theme: dokuloTheme(DkTokens.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Some entries never settle (spinners turn, skeletons pulse): pump past
    // the page transition instead.
    const transition = Duration(seconds: 1);
    for (final entry in catalogue) {
      // The list is longer than the screen: scroll the entry into view.
      await tester.scrollUntilVisible(
        find.text(entry.name),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(entry.name));
      await tester.pump(transition);
      // Light, then Dark; both are built (a tall entry's Dark half is below
      // the fold).
      expect(
        find.byWidget(entry.states, skipOffstage: false),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
      router.pop();
      await tester.pump(transition);
    }
  });

  testWidgets('an unknown component says so', (tester) async {
    final router = buildRouter(initialLocation: '/dev/catalogue/DkNope');
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
    expect(find.text('No component called "DkNope"'), findsOneWidget);
  });
}
