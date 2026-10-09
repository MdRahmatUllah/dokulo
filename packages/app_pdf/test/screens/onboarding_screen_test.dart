import 'package:app_pdf/components/dk_illustration.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/onboarding_providers.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/screens/launch/launch_screen.dart';
import 'package:app_pdf/screens/onboarding/onboarding_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The flag without the file system: seen or not, and what complete() did.
class _Flag extends OnboardingDone {
  _Flag(this.seen);
  bool seen;

  @override
  Future<bool> build() async => seen;

  @override
  Future<void> complete() async {
    seen = true;
    state = const AsyncData(true);
  }
}

Future<(GoRouter, _Flag)> pumpAt(
  WidgetTester tester,
  String location, {
  bool seen = false,
  DkTokens? tokens,
  Locale locale = const Locale('en'),
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final flag = _Flag(seen);
  final router = buildRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [onboardingDoneProvider.overrideWith(() => flag)],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: dokuloTheme(tokens ?? DkTokens.light),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (router, flag);
}

Finder get next => find.text('Next');

void main() {
  group('goldens', () {
    for (final (name, tokens, locale, size) in [
      ('light_en', DkTokens.light, const Locale('en'), const Size(393, 852)),
      ('dark_en', DkTokens.dark, const Locale('en'), const Size(393, 852)),
      ('light_de', DkTokens.light, const Locale('de'), const Size(393, 852)),
      ('light_en_se', DkTokens.light, const Locale('en'), const Size(375, 667)),
    ]) {
      testWidgets(name, (tester) async {
        await pumpAt(
          tester,
          Routes.welcome,
          tokens: tokens,
          locale: locale,
          size: size,
        );
        final pages = size.width < 393 ? 1 : 3; // the SE frame: O1 only
        for (var page = 1; page <= pages; page++) {
          await expectLater(
            find.byType(OnboardingScreen),
            matchesGoldenFile('goldens/onboarding_o${page}_$name.png'),
          );
          expect(tester.takeException(), isNull, reason: 'no overflow');
          if (page < pages) {
            await tester.drag(find.byType(PageView), const Offset(-300, 0));
            await tester.pumpAndSettle();
          }
        }
      });
    }
  });

  testWidgets('Next and swipe both advance; the dots follow', (tester) async {
    await pumpAt(tester, Routes.welcome);
    expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);
    expect(find.text('All your PDF tools. Nothing uploaded.'), findsOneWidget);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('No watermark. No subscription.'), findsOneWidget);
    expect(find.bySemanticsLabel('Page 2 of 3'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('What do you want to do first?'), findsOneWidget);
    expect(next, findsNothing, reason: 'O3: the cards are the buttons');
  });

  testWidgets('Skip lands on Home and marks onboarding seen', (tester) async {
    final (router, flag) = await pumpAt(tester, Routes.welcome);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.home);
    expect(flag.seen, isTrue);
  });

  testWidgets('back leaves like Skip: Home, and marks it seen', (tester) async {
    final (router, flag) = await pumpAt(tester, Routes.welcome);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.home);
    expect(flag.seen, isTrue);
  });

  for (final (card, location) in [
    ('Scan a document', Routes.scan),
    ('Open a PDF', Routes.files),
    ('Look around', Routes.home),
  ]) {
    testWidgets('O3 "$card" goes to $location and marks it seen', (
      tester,
    ) async {
      final (router, flag) = await pumpAt(tester, Routes.welcome);
      for (var i = 0; i < 2; i++) {
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      expect(
        find.byType(DkIllustration),
        findsOneWidget,
        reason: 'ILL-03 above the cards',
      );
      // One labelled button per card.
      final label = RegExp('^${RegExp.escape(card)}\n');
      expect(find.bySemanticsLabel(label), findsOneWidget);
      await tester.tap(find.text(card));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, location);
      expect(flag.seen, isTrue);
    });
  }

  testWidgets('every O3 card is at least 72 tall and 48 to touch', (
    tester,
  ) async {
    await pumpAt(tester, Routes.welcome);
    for (var i = 0; i < 2; i++) {
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  group('launch', () {
    for (final (seen, location) in [
      (false, Routes.welcome),
      (true, Routes.home),
    ]) {
      testWidgets('seen: $seen → $location', (tester) async {
        final (router, _) = await pumpAt(tester, Routes.launch, seen: seen);
        expect(find.byType(LaunchScreen), findsNothing);
        expect(router.state.uri.path, location);
      });
    }
  });
}
