import 'package:app_pdf/catalogue/badge_pill_states.dart';
import 'package:app_pdf/components/dk_count_badge.dart';
import 'package:app_pdf/components/dk_hint_pill.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Widget child, {
  DkTokens? tokens,
  double scale = 1,
  Locale locale = const Locale('en'),
  bool reduce = false,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: reduce),
    child: app!,
  ),
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

BoxDecoration decoration(WidgetTester tester, Type of) =>
    tester
            .widget<Container>(
              find.descendant(
                of: find.byType(of).first,
                matching: find.byType(Container),
              ),
            )
            .decoration!
        as BoxDecoration;

void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
      final file = 'badge_pill_${theme}_${lang}_${(scale * 100).round()}';
      testWidgets('golden: $file', (tester) async {
        tester.view.physicalSize = Size(393, scale > 1 ? 440 : 200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            const DkBadgePillGallery(),
            tokens: tokens,
            scale: scale,
            locale: Locale(lang),
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/$file.png'),
        );
      });
    }
  }

  group('DkCountBadge (DK-0114)', () {
    testWidgets('18 dp, grows with the number; primary with onPrimary text', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(const Row(children: [DkCountBadge(3), DkCountBadge(128)])),
      );
      final one = tester.getSize(find.byType(DkCountBadge).first);
      final three = tester.getSize(find.byType(DkCountBadge).last);
      expect(one.height, 18);
      expect(one.width, greaterThanOrEqualTo(18));
      expect(three.height, 18);
      expect(three.width, greaterThan(one.width));
      final d = decoration(tester, DkCountBadge);
      expect(d.color, DkTokens.light.color.primary);
      expect(
        tester.widget<Text>(find.text('3')).style!.color,
        DkTokens.light.color.onPrimary,
      );
    });

    testWidgets(
      'a new count pops (×1.35 at its peak); none with Reduce Motion',
      (tester) async {
        Future<double> peak({required bool reduce}) async {
          var n = 1;
          late StateSetter set;
          await tester.pumpWidget(
            app(
              StatefulBuilder(
                builder: (context, s) {
                  set = s;
                  return DkCountBadge(n);
                },
              ),
              reduce: reduce,
            ),
          );
          set(() => n = 2);
          await tester.pump();
          var max = 1.0;
          for (var i = 0; i < 16; i++) {
            await tester.pump(const Duration(milliseconds: 20));
            final scale = tester
                .widget<Transform>(
                  find.descendant(
                    of: find.byType(DkCountBadge),
                    matching: find.byType(Transform),
                  ),
                )
                .transform
                .getMaxScaleOnAxis();
            if (scale > max) max = scale;
          }
          await tester.pumpAndSettle();
          expect(find.text('2'), findsOneWidget);
          return max;
        }

        expect(await peak(reduce: false), closeTo(1.35, 0.05));
        expect(await peak(reduce: true), 1.0);
      },
    );

    testWidgets('a screen reader hears the label, or the number', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(
          const Column(
            children: [
              DkCountBadge(3, semanticsLabel: '3 pages'),
              DkCountBadge(7),
            ],
          ),
        ),
      );
      expect(find.bySemanticsLabel('3 pages'), findsOneWidget);
      expect(find.bySemanticsLabel('7'), findsOneWidget);
      handle.dispose();
    });
  });

  group('DkHintPill (DK-0116)', () {
    testWidgets('32 dp, camera chrome, onCamera labelL; a live region', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(const DkHintPill('Hold steady')));
      expect(tester.getSize(find.byType(DkHintPill)).height, 32);
      expect(
        decoration(tester, DkHintPill).color,
        DkTokens.light.color.cameraChrome,
      );
      final style = tester.widget<Text>(find.text('Hold steady')).style!;
      expect(style.color, DkTokens.light.color.onCamera);
      expect(style.fontSize, DkTokens.light.text.labelL.fontSize);
      expect(
        tester.getSemantics(find.byType(DkHintPill)),
        isSemantics(label: 'Hold steady', isLiveRegion: true),
      );
      handle.dispose();
    });
  });
}
