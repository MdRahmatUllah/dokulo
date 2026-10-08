import 'package:app_pdf/catalogue/feedback_states.dart';
import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/components/dk_mini_job_bar.dart';
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

void phone(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget bar({VoidCallback? onTap, int jobs = 1, double progress = 0.45}) =>
    DkMiniJobBar(
      icon: DkIcons.tool('compress'),
      label: 'Compressing · 18 of 40',
      progress: progress,
      jobs: jobs,
      onTap: onTap ?? () {},
    );

void main() {
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
      final file = 'mini_job_bar_${name}_${lang}_${(scale * 100).round()}';
      testWidgets('golden: $file', (tester) async {
        phone(tester, Size(393, scale > 1 ? 480 : 320));
        await tester.pumpWidget(
          app(
            const MiniJobBarStates(),
            tokens: tokens,
            scale: scale,
            locale: Locale(lang),
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MiniJobBarStates),
          matchesGoldenFile('goldens/$file.png'),
        );
      });
    }
  }

  testWidgets('48 tall, 8 from the edges; the progress line is 2 dp at 45 %', (
    tester,
  ) async {
    phone(tester, const Size(393, 300));
    await tester.pumpWidget(app(Center(child: bar())));
    final box = tester.getRect(
      find.descendant(
        of: find.byType(DkMiniJobBar),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(box.height, 48);
    expect(box.left, 8);
    expect(box.right, 393 - 8);
    final line = tester.getRect(
      find.descendant(
        of: find.byType(DkMiniJobBar),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(line.height, 2);
    expect(line.width, closeTo(box.width * 0.45, 0.5));
    expect(line.bottom, box.bottom);
  });

  testWidgets('one button for screen readers: the job and its percent; a '
      'tap or Enter opens the sheet', (tester) async {
    phone(tester, const Size(393, 300));
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(app(Center(child: bar(onTap: () => taps++))));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Compressing · 18 of 40')),
      isSemantics(
        isButton: true,
        label: 'Compressing · 18 of 40',
        value: '45 %',
        hasTapAction: true,
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await tester.tap(find.byType(DkMiniJobBar));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('several jobs: "3 jobs running" in EN and DE', (tester) async {
    phone(tester, const Size(393, 300));
    await tester.pumpWidget(app(Center(child: bar(jobs: 3))));
    expect(find.text('3 jobs running'), findsOne);
    await tester.pumpWidget(
      app(Center(child: bar(jobs: 3)), locale: const Locale('de')),
    );
    expect(find.text('3 Aufgaben laufen'), findsOne);
  });

  testWidgets('at 200 % the label wraps and the bar grows: nothing is cut', (
    tester,
  ) async {
    phone(tester, const Size(393, 400));
    await tester.pumpWidget(app(Center(child: bar()), scale: 2));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(DkMiniJobBar)).height, greaterThan(48));
  });
}
