import 'package:app_pdf/components/dk_scan_button.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/catalogue/scan_button_states.dart';
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
        tester.view.physicalSize = const Size(393, 560);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 24,
                children: [DkScanButtonGallery()],
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
          matchesGoldenFile('goldens/dk_scan_button_$name.png'),
        );
      });
    }
  }

  group('DkScanButton (DK-0078)', () {
    testWidgets('a 64 dp primary circle in a 4 dp background ring, "Scan" '
        'below', (tester) async {
      await tester.pumpWidget(
        app(
          Center(
            child: DkScanButton(onPressed: () {}, onMode: (_) {}),
          ),
        ),
      );
      final circle = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
      );
      expect(tester.getSize(circle), const Size(72, 72));
      final d = tester.widget<Container>(circle).decoration! as BoxDecoration;
      expect(d.color, DkTokens.light.color.primary);
      expect(d.border!.top.color, DkTokens.light.color.background);
      expect(d.border!.top.width, 4);
      expect(d.boxShadow, DkTokens.light.elevation.floating);
      expect(find.text('Scan'), findsOneWidget);
    });

    testWidgets('pressed scales to 0.94; release returns with emphasis', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        app(
          Center(
            child: DkScanButton(onPressed: () => taps++, onMode: (_) {}),
          ),
        ),
      );
      double scale() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
      final g = await tester.startGesture(
        tester.getCenter(find.byType(AnimatedScale)),
      );
      // With a long press listening too, the tap lands after 100 ms.
      await tester.pump(const Duration(milliseconds: 150));
      expect(scale(), 0.94);
      await g.up();
      await tester.pump();
      expect(scale(), 1);
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
        const Duration(milliseconds: 320),
      );
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('long press: the five modes; a pick reports the mode', (
      tester,
    ) async {
      DkScanMode? picked;
      await tester.pumpWidget(
        app(
          Align(
            alignment: Alignment.bottomCenter,
            child: DkScanButton(onPressed: () {}, onMode: (m) => picked = m),
          ),
          locale: const Locale('de'),
        ),
      );
      await tester.longPress(find.byType(AnimatedScale));
      await tester.pumpAndSettle();
      for (final label in [
        'Dokument',
        'Ausweis',
        'Buch',
        'Stapelverarbeitung',
        'Fotos importieren',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('Buch'));
      await tester.pumpAndSettle();
      expect(picked, DkScanMode.book);
    });

    testWidgets('semantics: "Scan", with the long-press hint', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(
          Center(
            child: DkScanButton(onPressed: () {}, onMode: (_) {}),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(AnimatedScale)),
        matchesSemantics(
          label: 'Scan',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasLongPressAction: true,
          onLongPressHint: 'Choose a scan mode',
        ),
      );
      handle.dispose();
    });
  });
}
