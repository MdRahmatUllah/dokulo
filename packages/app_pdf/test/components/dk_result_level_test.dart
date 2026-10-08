import 'package:app_pdf/catalogue/result_level_states.dart';
import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/components/dk_level_card.dart';
import 'package:app_pdf/components/dk_result_card.dart';
import 'package:app_pdf/components/motion/dk_success_tick.dart';
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
  double width = 393,
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
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width - 32, child: child),
      ),
    ),
  ),
);

const levels = [
  (0, (title: 'Light', estimate: '≈ 6.1 MB', description: 'Best quality')),
  (1, (title: 'Recommended', estimate: '≈ 1.9 MB', description: 'Email')),
  (2, (title: 'Strong', estimate: '≈ 0.8 MB', description: 'Smallest')),
];

void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
      final name = '${theme}_${lang}_${(scale * 100).round()}';
      testWidgets('golden: $name', (tester) async {
        tester.view.physicalSize = Size(393, scale > 1 ? 1500 : 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            const SingleChildScrollView(child: DkResultLevelGallery()),
            tokens: tokens,
            scale: scale,
            locale: Locale(lang),
          ),
        );
        await tester.pumpAndSettle(); // the tick has drawn
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/result_level_$name.png'),
        );
      });
    }
  }

  group('DkResultCard (DK-0090)', () {
    testWidgets('done: successContainer, the tick, the number and delta', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(
          const DkResultCard(
            headline: '1.9 MB',
            delta: '(−77 %)',
            sub: 'From 8.4 MB',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DkSuccessTick), findsOneWidget);
      final box =
          tester.widget<Container>(find.byType(Container).first).decoration!
              as BoxDecoration;
      expect(box.color, DkTokens.light.color.successContainer);
      expect(
        tester.widget<Text>(find.text('(−77 %)')).style!.color,
        DkTokens.light.color.success,
      );
      expect(find.bySemanticsLabel('1.9 MB (−77 %)'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('partial: warning tint and icon', (tester) async {
      await tester.pumpWidget(
        app(const DkResultCard(headline: '10 of 12', sub: 's', partial: true)),
      );
      expect(find.byIcon(DkIcons.warning), findsOneWidget);
      expect(find.byType(DkSuccessTick), findsNothing);
      final box =
          tester.widget<Container>(find.byType(Container).first).decoration!
              as BoxDecoration;
      expect(box.color, DkTokens.light.color.warningContainer);
    });

    testWidgets('the number counts up after the tick', (tester) async {
      await tester.pumpWidget(
        app(
          DkResultCard(
            headline: '1.9 MB',
            sub: 's',
            countFrom: 8.4,
            countTo: 1.9,
            format: (v) => '${v.toStringAsFixed(1)} MB',
          ),
        ),
      );
      expect(find.text('8.4 MB'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('1.9 MB'), findsOneWidget);
    });
  });

  group('DkLevelCards (DK-0092)', () {
    testWidgets('a row of three; the selected one ringed with a check', (
      tester,
    ) async {
      int? picked;
      await tester.pumpWidget(
        app(
          DkLevelCards<int>(
            levels: levels,
            selected: 1,
            onChanged: (v) => picked = v,
          ),
        ),
      );
      final y = {
        for (final t in ['Light', 'Recommended', 'Strong'])
          tester.getTopLeft(find.text(t)).dy,
      };
      expect(y, hasLength(1), reason: 'one row');
      expect(find.byIcon(DkIcons.check), findsOneWidget);
      await tester.tap(find.text('Strong'));
      expect(picked, 2);
    });

    testWidgets('stacks below 360 dp and at 160 % text', (tester) async {
      Future<int> rows({double width = 393, double scale = 1}) async {
        await tester.pumpWidget(
          app(
            DkLevelCards<int>(levels: levels, selected: 0, onChanged: (_) {}),
            width: width,
            scale: scale,
          ),
        );
        return {
          for (final t in ['Light', 'Recommended', 'Strong'])
            tester.getTopLeft(find.text(t)).dy,
        }.length;
      }

      expect(await rows(width: 340), 3);
      expect(await rows(scale: 1.6), 3);
      expect(await rows(), 1);
    });
  });
}
