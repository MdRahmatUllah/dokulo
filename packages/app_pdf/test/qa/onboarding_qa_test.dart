import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/screens/launch/launch_screen.dart';
import 'package:app_pdf/screens/onboarding/onboarding_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../app_overrides.dart';

// Visual QA (DK-0710..DK-0714): the 01-onboarding frames (launch, o1, o2,
// o3, and o1 on an iPhone SE), rendered by the real screens at the frames'
// sizes. The goldens sit next to the frames' screenshots in
// docs/qa/onboarding/; the findings are in docs/qa/onboarding.md.
void main() {
  Future<void> board(
    WidgetTester tester,
    Widget screen, {
    required DkTokens tokens,
    Locale locale = const Locale('en'),
    Size size = const Size(393, 852),
    int next = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: homeOverrides(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dokuloTheme(tokens),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < next; i++) {
      await tester.tap(
        find.text(locale.languageCode == 'de' ? 'Weiter' : 'Next'),
      );
      await tester.pumpAndSettle();
    }
  }

  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (frame, next) in [('o1', 0), ('o2', 1), ('o3', 2)]) {
      testWidgets('onboarding-$frame, $theme', (tester) async {
        await board(
          tester,
          const OnboardingScreen(),
          tokens: tokens,
          next: next,
        );
        await expectLater(
          find.byType(OnboardingScreen),
          matchesGoldenFile('goldens/qa_onboarding_${frame}_$theme.png'),
        );
      });
    }
    testWidgets('onboarding-o1-iphone-se, $theme', (tester) async {
      await board(
        tester,
        const OnboardingScreen(),
        tokens: tokens,
        size: const Size(375, 667),
      );
      await expectLater(
        find.byType(OnboardingScreen),
        matchesGoldenFile('goldens/qa_onboarding_o1_se_$theme.png'),
      );
    });
    testWidgets('onboarding-launch, $theme', (tester) async {
      // The launch screen leaves at once (to Home or the intro): its first
      // frame is the board.
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const LaunchScreen()),
          GoRoute(path: '/home', builder: (_, _) => const SizedBox()),
          GoRoute(path: '/welcome', builder: (_, _) => const SizedBox()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: homeOverrides(),
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: dokuloTheme(tokens),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(LaunchScreen),
        matchesGoldenFile('goldens/qa_onboarding_launch_$theme.png'),
      );
    });
  }
}
