import 'package:app_pdf/catalogue/overlay_states.dart';
import 'package:app_pdf/components/dk_loading_spinner.dart';
import 'package:app_pdf/components/dk_skeleton.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Widget child, {
  DkTokens? tokens,
  Locale locale = const Locale('en'),
  bool reduceMotion = false,
  TargetPlatform? platform,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light).copyWith(platform: platform),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: child!,
  ),
  home: Scaffold(body: child),
);

double opacityOf(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.descendant(
        of: find.byType(DkSkeleton),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

void main() {
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    // No text in them, so no 200 % variant; the pulse is caught at rest.
    testWidgets('skeletons and spinners, $name', (tester) async {
      tester.view.physicalSize = const Size(393, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(const LoadingStates(), tokens: tokens, reduceMotion: true),
      );
      // Let the spinners draw an arc (they start as an empty one).
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(
        find.byType(LoadingStates),
        matchesGoldenFile('goldens/loading_$name.png'),
      );
    });
  }

  testWidgets('the pulse: 1 → 0.55 → 1 in 1.2 s; still with Reduce Motion', (
    tester,
  ) async {
    await tester.pumpWidget(app(DkSkeleton.fileRows()));
    expect(opacityOf(tester), 1);
    await tester.pump(const Duration(milliseconds: 600));
    expect(opacityOf(tester), closeTo(0.55, 0.01));
    await tester.pump(const Duration(milliseconds: 600));
    expect(opacityOf(tester), closeTo(1, 0.01));

    await tester.pumpWidget(app(DkSkeleton.fileRows(), reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 300));
    final still = opacityOf(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(opacityOf(tester), still);
  });

  testWidgets('blocks are surfaceSunken with radius.xs', (tester) async {
    await tester.pumpWidget(app(const DkSkeleton.page()));
    final block = tester.widget<Container>(
      find.descendant(
        of: find.byType(DkSkeletonBlock),
        matching: find.byType(Container),
      ),
    );
    final d = block.decoration! as BoxDecoration;
    expect(d.color, DkTokens.light.color.surfaceSunken);
    expect(d.borderRadius, BorderRadius.circular(4));
  });

  testWidgets('the platform indicator at 20 and 32, in primary', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const Column(
          children: [
            DkLoadingSpinner(),
            DkLoadingSpinner(size: DkSpinnerSize.large),
          ],
        ),
        platform: TargetPlatform.android,
      ),
    );
    final rings = find.byType(CircularProgressIndicator);
    expect(tester.getSize(rings.at(0)), const Size(20, 20));
    expect(tester.getSize(rings.at(1)), const Size(32, 32));
    expect(
      tester.widget<CircularProgressIndicator>(rings.first).color,
      DkTokens.light.color.primary,
    );

    await tester.pumpWidget(
      app(const DkLoadingSpinner(), platform: TargetPlatform.iOS),
    );
    // The theme animates to iOS (its platform flips halfway); the spinner
    // never settles, so pump past the animation.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
  });

  testWidgets('screen readers hear "Loading" once, in EN and DE', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    for (final (locale, label) in [
      (const Locale('en'), 'Loading'),
      (const Locale('de'), 'Wird geladen'),
    ]) {
      await tester.pumpWidget(
        app(const DkSkeleton.modelCard(), locale: locale),
      );
      expect(find.bySemanticsLabel(label), findsOneWidget);
      // F1's six rows: one "Loading", not six.
      await tester.pumpWidget(app(DkSkeleton.fileRows(), locale: locale));
      expect(find.byType(DkSkeletonFileRow), findsNWidgets(6));
      expect(find.bySemanticsLabel(label), findsOneWidget);
      await tester.pumpWidget(app(const DkLoadingSpinner(), locale: locale));
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
    handle.dispose();
  });
}
