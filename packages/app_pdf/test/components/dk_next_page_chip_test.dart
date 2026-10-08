import 'package:app_pdf/catalogue/next_page_chip_states.dart';
import 'package:app_pdf/components/dk_next_chip.dart';
import 'package:app_pdf/components/dk_page_chip.dart';
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
    ('next_page_chip', const DkNextPageChipGallery(), 260.0),
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

  group('DkNextChip and DkPageChip (DK-0106, DK-0108)', () {
    testWidgets('next: the tool name from the catalogue, 36 dp, 48 to touch', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        app(
          Center(
            child: DkNextChip(toolId: 'compress', onTap: () => taps++),
          ),
          locale: const Locale('de'),
        ),
      );
      expect(find.text('PDF verkleinern'), findsOneWidget);
      expect(tester.getSize(find.byType(DkNextChip)).height, 48);
      await tester.tap(find.byType(DkNextChip));
      expect(taps, 1);
    });

    testWidgets(
      'page chip: "S. 3" in German, 44 to touch, says where it goes',
      (tester) async {
        final handle = tester.ensureSemantics();
        var taps = 0;
        await tester.pumpWidget(
          app(
            Center(child: DkPageChip(page: 3, onTap: () => taps++)),
            locale: const Locale('de'),
          ),
        );
        expect(find.text('S. 3'), findsOneWidget);
        final size = tester.getSize(find.byType(DkPageChip));
        expect(size.height, 44);
        expect(size.width, greaterThanOrEqualTo(44));
        expect(find.bySemanticsLabel('Zu Seite 3'), findsOneWidget);
        await tester.tap(find.byType(DkPageChip));
        expect(taps, 1);
        handle.dispose();
      },
    );
  });
}
