import 'package:app_pdf/catalogue/ai_states.dart';
import 'package:app_pdf/components/dk_ai_parts.dart';
import 'package:app_pdf/components/dk_ring.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_layout.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Widget child, {
  DkTokens? tokens,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery.withClampedTextScaling(
    minScaleFactor: textScale,
    maxScaleFactor: textScale,
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  final galleries = <String, Widget>{'ask': const AskStates()};
  for (final MapEntry(key: what, value: gallery) in galleries.entries) {
    for (final (name, tokens) in [
      ('light', DkTokens.light),
      ('dark', DkTokens.dark),
    ]) {
      for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
        final file = '${what}_${name}_${lang}_${(scale * 100).round()}';
        testWidgets('golden: $file', (tester) async {
          tester.view.physicalSize = Size(393, scale == 1 ? 400 : 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            app(
              gallery,
              tokens: tokens,
              textScale: scale,
              locale: Locale(lang),
            ),
          );
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byWidget(gallery),
            matchesGoldenFile('goldens/$file.png'),
          );
        });
      }
    }
  }

  testWidgets('DkSuggestionChip: a 48 target, two lines at most', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var asked = 0;
    await tester.pumpWidget(
      app(
        DkSuggestionChip(
          text:
              'A very long question that goes on and on and on and on and '
              'on and on and on and on and on and on and on and on',
          onTap: () => asked++,
        ),
      ),
    );
    final chip = find.byType(DkSuggestionChip);
    expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
    expect(tester.widget<Text>(find.byType(Text)).maxLines, 2);
    await tester.tap(chip);
    expect(asked, 1);
    // One button for screen readers, with the whole question.
    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('^A very long'))),
      isSemantics(isButton: true, hasTapAction: true),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('DkSuggestionChip by keyboard: the ring and Enter', (
    tester,
  ) async {
    var asked = 0;
    await tester.pumpWidget(
      app(DkSuggestionChip(text: 'What is due?', onTap: () => asked++)),
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    Finder ring() => find.byWidgetPredicate(
      (w) => w is DkRing && w.side == DkTokens.light.focusRing,
    );
    expect(ring(), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(ring(), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(asked, 1);
  });

  testWidgets('DkAIFooter names the model, in EN and DE', (tester) async {
    for (final (locale, text) in [
      (
        const Locale('en'),
        'On this phone · Gemma 4 E2B · AI can make mistakes',
      ),
      (
        const Locale('de'),
        'Auf diesem Handy · Gemma 4 E2B · KI kann Fehler machen',
      ),
    ]) {
      await tester.pumpWidget(
        app(const DkAIFooter(model: 'Gemma 4 E2B'), locale: locale),
      );
      expect(find.text(text), findsOneWidget);
    }
  });
}
