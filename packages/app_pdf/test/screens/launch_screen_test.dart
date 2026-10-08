import 'package:app_pdf/components/dk_logo.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/screens/launch/launch_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('the first frame is the splash ($theme), then Home', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = buildRouter(initialLocation: Routes.launch);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
            theme: dokuloTheme(tokens),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      // The native splash: the background, the 72 dp symbol in the middle
      // of the screen, nothing else.
      expect(find.byType(LaunchScreen), findsOneWidget);
      final box = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(LaunchScreen),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(box.color, tokens.color.background);
      final logo = find.byType(DkLogo);
      expect(tester.getCenter(logo), const Offset(393 / 2, 852 / 2));
      expect(tester.getSize(logo), Size.square(72 + 2 * DkLogo.clearSpace(72)));
      expect(find.byType(Text), findsNothing);
      // Then on to Home.
      await tester.pump();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, Routes.home);
      expect(find.byType(LaunchScreen), findsNothing);
    });
  }
}
