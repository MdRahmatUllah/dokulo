import 'package:app_pdf/components/dk_text_field.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/catalogue/range_search_states.dart';
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
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

OutlineInputBorder borderOf(WidgetTester tester, {bool focused = false}) {
  final d = tester.widget<TextField>(find.byType(TextField)).decoration!;
  return (focused ? d.focusedBorder : d.enabledBorder)! as OutlineInputBorder;
}

void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
      final name = '${theme}_${lang}_${(scale * 100).round()}';
      testWidgets('golden: $name', (tester) async {
        tester.view.physicalSize = Size(393, scale > 1 ? 900 : 560);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            const SingleChildScrollView(child: DkRangeSearchGallery()),
            tokens: tokens,
            scale: scale,
            locale: Locale(lang),
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/dk_range_search_$name.png'),
        );
      });
    }
  }

  group('DkRangeField and DkSearchField (DK-0124, DK-0126)', () {
    testWidgets('range: mono text, the example placeholder, Pick pages', (
      tester,
    ) async {
      var picked = 0;
      await tester.pumpWidget(app(DkRangeField(onPick: () => picked++)));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style!.fontFamily, DkTokens.light.text.mono.fontFamily);
      expect(field.decoration!.hintText, '1–3, 5, 8–end');
      await tester.tap(find.bySemanticsLabel('Pick pages'));
      expect(picked, 1);
    });

    testWidgets('search: 40 tall with the search icon and clear', (
      tester,
    ) async {
      await tester.pumpWidget(app(const DkSearchField(hint: 'Search tools')));
      expect(tester.getSize(find.byType(TextField)).height, 40);
      expect(
        tester.widget<TextField>(find.byType(TextField)).textInputAction,
        TextInputAction.search,
      );
      await tester.enterText(find.byType(TextField), 'comp');
      await tester.pump();
      expect(find.bySemanticsLabel('Clear'), findsOneWidget);
    });
  });
}
