import 'package:app_pdf/catalogue/page_pill_states.dart';
import 'package:app_pdf/components/dk_page_pill.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/theme/haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The haptics the components asked for.
final played = <String>[];

Widget app(
  Widget child, {
  DkTokens? tokens,
  double scale = 1,
  Locale locale = const Locale('en'),
  bool reduce = false,
}) => ProviderScope(
  overrides: [
    hapticsProvider.overrideWithValue(
      DkHaptics(
        selection: () async => played.add('selection'),
        light: () async => played.add('light'),
        medium: () async => played.add('medium'),
      ),
    ),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dokuloTheme(tokens ?? DkTokens.light),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        disableAnimations: reduce,
      ),
      child: app!,
    ),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

void main() {
  setUp(played.clear);

  for (final (name, gallery, height) in [
    ('page_pill', const DkPagePillGallery(), 160.0),
  ]) {
    for (final (theme, tokens) in [
      ('light', DkTokens.light),
      ('dark', DkTokens.dark),
    ]) {
      for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
        final file = '${name}_${theme}_${lang}_${(scale * 100).round()}';
        testWidgets('golden: $file', (tester) async {
          tester.view.physicalSize = Size(393, height * (scale > 1 ? 1.8 : 1));
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            app(
              gallery,
              tokens: tokens,
              scale: scale,
              locale: Locale(lang),
              reduce: true, // the running dot holds still for the golden
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile('goldens/$file.png'),
          );
        });
      }
    }
  }

  testWidgets('DkPagePill (DK-0118): "3 / 12", 28 dp, read as "Page 3 of 12"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      app(const Center(child: DkPagePill(page: 3, count: 12))),
    );
    expect(find.text('3 / 12'), findsOneWidget);
    expect(tester.getSize(find.byType(DkPagePill)).height, 28);
    expect(find.bySemanticsLabel('Page 3 of 12'), findsOneWidget);
    handle.dispose();
  });
}
