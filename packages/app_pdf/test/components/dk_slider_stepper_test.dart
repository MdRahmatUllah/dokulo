import 'package:app_pdf/components/dk_slider.dart';
import 'package:app_pdf/components/dk_stepper.dart';
import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/catalogue/slider_stepper_states.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Widget child, {
  DkTokens? tokens,
  double scale = 1,
  Locale locale = const Locale('en'),
  TargetPlatform? platform,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light).copyWith(platform: platform),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: app!,
  ),
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
      final name = '${theme}_${lang}_${(scale * 100).round()}';
      testWidgets('golden: $name', (tester) async {
        tester.view.physicalSize = Size(393, scale > 1 ? 560 : 360);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            const SingleChildScrollView(child: DkSliderStepperGallery()),
            tokens: tokens,
            scale: scale,
            locale: Locale(lang),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/dk_slider_stepper_$name.png'),
        );
      });
    }
  }

  testWidgets('DkSlider: 4 dp track, 20 dp white thumb, the value right of '
      'the title', (tester) async {
    double? value;
    await tester.pumpWidget(
      app(
        DkSlider(
          title: 'Opacity',
          value: 0.3,
          onChanged: (v) => value = v,
          format: (v) => '${(v * 100).round()} %',
        ),
      ),
    );
    final theme = tester.widget<SliderTheme>(find.byType(SliderTheme)).data;
    expect(theme.trackHeight, 4);
    expect(theme.activeTrackColor, DkTokens.light.color.primary);
    expect(theme.inactiveTrackColor, DkTokens.light.color.outline);
    expect(theme.thumbColor, DkTokens.light.color.pageWhite);
    expect((theme.thumbShape! as RoundSliderThumbShape).enabledThumbRadius, 10);
    expect(find.text('30 %'), findsOneWidget);
    expect(
      tester.getCenter(find.text('30 %')).dx,
      greaterThan(tester.getCenter(find.text('Opacity')).dx),
    );
    await tester.tap(find.byType(Slider));
    expect(value, isNotNull);
  });

  group('DkStepper (DK-0134)', () {
    testWidgets('− and + change the value; the bound disables a button', (
      tester,
    ) async {
      var n = 2;
      await tester.pumpWidget(
        app(
          StatefulBuilder(
            builder: (context, set) => DkStepper(
              value: n,
              min: 1,
              max: 3,
              onChanged: (v) => set(() => n = v),
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(DkIcons.add));
      await tester.pump();
      expect(n, 3);
      await tester.tap(find.byIcon(DkIcons.add));
      await tester.pump();
      expect(n, 3, reason: 'max reached: + is disabled');
      await tester.tap(find.byIcon(DkIcons.remove));
      await tester.pump();
      await tester.tap(find.byIcon(DkIcons.remove));
      await tester.pump();
      expect(n, 1);
      expect(
        tester
            .getSize(
              find
                  .byWidgetPredicate(
                    (w) => w is Container && w.constraints?.maxWidth == 36,
                  )
                  .first,
            )
            .width,
        36,
      );
    });

    testWidgets('screen readers: one adjustable value', (tester) async {
      final handle = tester.ensureSemantics();
      var n = 5;
      await tester.pumpWidget(
        app(
          StatefulBuilder(
            builder: (context, set) => DkStepper(
              value: n,
              label: 'Start at',
              onChanged: (v) => set(() => n = v),
            ),
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(DkStepper));
      expect(node.label, 'Start at');
      expect(node.value, '5');
      expect(node.increasedValue, '6');
      tester.semantics.performAction(
        find.semantics.byLabel('Start at'),
        SemanticsAction.increase,
      );
      await tester.pump();
      expect(n, 6);
      handle.dispose();
    });
  });
}
