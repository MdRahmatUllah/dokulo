import 'package:app_pdf/catalogue/color_pin_states.dart';
import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/components/dk_color_row.dart';
import 'package:app_pdf/components/dk_pin_pad.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        tester.view.physicalSize = Size(393, scale > 1 ? 300 : 200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            const DkColorRowGallery(),
            tokens: tokens,
            scale: scale,
            locale: Locale(lang),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/dk_color_row_$name.png'),
        );
      });
      testWidgets('golden: pin pad $name', (tester) async {
        tester.view.physicalSize = Size(393, scale > 1 ? 800 : 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            const DkPinPadGallery(),
            tokens: tokens,
            scale: scale,
            locale: Locale(lang),
          ),
        );
        await tester.tap(find.bySemanticsLabel('1'));
        await tester.tap(find.bySemanticsLabel('2'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/dk_pin_pad_$name.png'),
        );
      });
    }
  }

  group('DkColorRow (DK-0142)', () {
    testWidgets('names announced; selected ringed 3 dp with a check', (
      tester,
    ) async {
      Color? picked;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => DkColorRow(
              swatches: markupSwatches(
                context.tokens,
                AppLocalizations.of(context),
              ),
              selected: DkTokens.light.markup.blue,
              onChanged: (c) => picked = c,
            ),
          ),
          locale: const Locale('de'),
        ),
      );
      for (final n in [
        'Gelb',
        'Grün',
        'Blau',
        'Pink',
        'Rot',
        'Schwarz',
        'Eigene',
      ]) {
        expect(find.bySemanticsLabel(n), findsOneWidget);
      }
      expect(
        find.descendant(
          of: find.bySemanticsLabel('Blau'),
          matching: find.byIcon(DkIcons.check),
        ),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel('Rot'));
      expect(picked, DkTokens.light.markup.red);
    });

    testWidgets('Custom opens the hue and brightness picker', (tester) async {
      Color? picked;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => DkColorRow(
              swatches: markupSwatches(
                context.tokens,
                AppLocalizations.of(context),
              ),
              selected: DkTokens.light.markup.blue,
              onChanged: (c) => picked = c,
            ),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Custom'));
      await tester.pumpAndSettle();
      expect(find.text('Hue'), findsOneWidget);
      expect(find.text('Brightness'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(picked, isNotNull);
    });
  });

  group('DkPinPad (DK-0148)', () {
    testWidgets('six digits complete the PIN; delete removes one', (
      tester,
    ) async {
      String? pin;
      await tester.pumpWidget(
        app(Center(child: DkPinPad(onComplete: (p) => pin = p))),
      );
      for (final d in ['1', '2', '3', '4', '5']) {
        await tester.tap(find.bySemanticsLabel(d));
      }
      await tester.tap(find.bySemanticsLabel('Delete digit'));
      await tester.tap(find.bySemanticsLabel('9'));
      await tester.tap(find.bySemanticsLabel('0'));
      expect(pin, '123490');
      final key = tester.widget<Container>(
        find
            .ancestor(of: find.text('7'), matching: find.byType(Container))
            .first,
      );
      expect(key.constraints, BoxConstraints.tight(const Size(72, 72)));
    });

    testWidgets('a hardware keyboard types and deletes', (tester) async {
      String? pin;
      await tester.pumpWidget(
        app(Center(child: DkPinPad(onComplete: (p) => pin = p))),
      );
      await tester.pump();
      for (final k in [
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit7,
        LogicalKeyboardKey.backspace,
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit0,
        LogicalKeyboardKey.digit5,
        LogicalKeyboardKey.digit8,
      ]) {
        await tester.sendKeyEvent(k);
      }
      expect(pin, '421058');
    });

    testWidgets('a wrong PIN shakes the dots; not with Reduce Motion', (
      tester,
    ) async {
      Widget pad(int errors, {bool reduce = false}) => app(
        Center(
          child: DkPinPad(onComplete: (_) {}, errorCount: errors),
        ),
        reduce: reduce,
      );
      double dx() => tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .getTranslation()
          .x;
      await tester.pumpWidget(pad(0));
      await tester.pumpWidget(pad(1));
      await tester.pump(const Duration(milliseconds: 40));
      expect(dx().abs(), greaterThan(1));
      await tester.pumpAndSettle();
      expect(dx(), 0);

      await tester.pumpWidget(pad(1, reduce: true));
      await tester.pumpWidget(pad(2, reduce: true));
      await tester.pump(const Duration(milliseconds: 40));
      expect(dx(), 0);
    });
  });
}
