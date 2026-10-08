import 'package:app_pdf/components/dk_shutter_button.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/catalogue/shutter_button_states.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Widget child, {
  DkTokens? tokens,
  double scale = 1,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: app!,
  ),
  home: Scaffold(body: child),
);

void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
      final name = '${theme}_${lang}_${(scale * 100).round()}';
      testWidgets('golden: $name', (tester) async {
        tester.view.physicalSize = const Size(393, 320);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 24,
                children: [DkShutterButtonGallery()],
              ),
            ),
            tokens: tokens,
            scale: scale,
            locale: Locale(lang),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/dk_shutter_button_$name.png'),
        );
      });
    }
  }

  group('DkShutterButton (DK-0080)', () {
    testWidgets('72 dp, the 58 dp disc shrinks to 52 when pressed', (
      tester,
    ) async {
      var shots = 0;
      await tester.pumpWidget(
        app(Center(child: DkShutterButton(onPressed: () => shots++))),
      );
      expect(tester.getSize(find.byType(DkShutterButton)), const Size(72, 72));
      Size disc() => tester.getSize(find.byType(AnimatedContainer));
      expect(disc(), const Size(58, 58));
      final g = await tester.startGesture(
        tester.getCenter(find.byType(DkShutterButton)),
      );
      await tester.pumpAndSettle();
      expect(disc(), const Size(52, 52));
      await g.up();
      await tester.pumpAndSettle();
      expect(disc(), const Size(58, 58));
      expect(shots, 1);
    });

    testWidgets('the countdown follows the auto-capture animation, 0.5 s', (
      tester,
    ) async {
      final timer = AnimationController(
        vsync: const TestVSync(),
        duration: DkTokens.light.motion.autoCapture,
      );
      addTearDown(timer.dispose);
      var captured = false;
      timer.addStatusListener((s) {
        if (s == AnimationStatus.completed) captured = true;
      });
      await tester.pumpWidget(
        app(
          Center(
            child: AnimatedBuilder(
              animation: timer,
              builder: (_, _) =>
                  DkShutterButton(onPressed: () {}, countdown: timer.value),
            ),
          ),
        ),
      );
      double progress() =>
          (tester
                          .widget<CustomPaint>(
                            find.descendant(
                              of: find.byType(DkShutterButton),
                              matching: find.byType(CustomPaint),
                            ),
                          )
                          .painter!
                      as dynamic)
                  .progress
              as double;
      timer.forward();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(progress(), closeTo(0.5, 0.05));
      expect(captured, isFalse);
      await tester.pump(const Duration(milliseconds: 260));
      expect(progress(), 1);
      expect(captured, isTrue, reason: 'the arc closes as the capture fires');
    });

    testWidgets('disabled (no permission) is 40 % and ignores taps; labelled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(const Center(child: DkShutterButton(onPressed: null))),
      );
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.4);
      expect(
        tester.getSemantics(find.byType(DkShutterButton)),
        matchesSemantics(
          label: 'Take photo',
          isButton: true,
          hasEnabledState: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('Reduce Motion: the disc stays 58 while pressed', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: app(Center(child: DkShutterButton(onPressed: () {}))),
        ),
      );
      final g = await tester.startGesture(
        tester.getCenter(find.byType(DkShutterButton)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(AnimatedContainer)),
        const Size(58, 58),
      );
      await g.up();
    });

    testWidgets('tap target and label guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(Center(child: DkShutterButton(onPressed: () {}))),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
