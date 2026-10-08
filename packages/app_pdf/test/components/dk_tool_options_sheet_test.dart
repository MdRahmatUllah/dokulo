import 'package:app_pdf/catalogue/tool_options_states.dart';
import 'package:app_pdf/components/dk_segmented.dart';
import 'package:app_pdf/components/dk_slider.dart';
import 'package:app_pdf/components/dk_stepper.dart';
import 'package:app_pdf/components/dk_tool_options_sheet.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Widget home, {
  DkTokens? tokens,
  double scale = 1,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: SingleChildScrollView(child: home)),
);

Widget sheet(DkMarkupKind kind, List<DkToolOptions> changes) => Padding(
  padding: const EdgeInsets.all(24),
  child: DkToolOptionsSheet(
    kind: kind,
    options: DkToolOptions(color: const DkMarkup().red),
    onChanged: changes.add,
    colorRow: const SizedBox(key: Key('colours'), height: 32),
  ),
);

void main() {
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
      final file = 'tool_options_${name}_${lang}_${(scale * 100).round()}';
      testWidgets('golden: $file', (tester) async {
        tester.view.physicalSize = const Size(393, 2000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            const ToolOptionsStates(),
            tokens: tokens,
            scale: scale,
            locale: Locale(lang),
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(ToolOptionsStates),
          matchesGoldenFile('goldens/$file.png'),
        );
      });
    }
  }

  testWidgets('each tool shows what it has', (tester) async {
    for (final (kind, sliders, stepper, segmented, colours) in [
      (DkMarkupKind.pen, 1, false, false, true),
      (DkMarkupKind.highlighter, 2, false, false, true),
      (DkMarkupKind.text, 0, true, false, true),
      (DkMarkupKind.shape, 1, false, true, true),
      (DkMarkupKind.eraser, 0, false, true, false),
    ]) {
      await tester.pumpWidget(app(sheet(kind, [])));
      expect(find.byType(DkSlider), findsNWidgets(sliders), reason: '$kind');
      expect(find.byType(DkStepper), stepper ? findsOne : findsNothing);
      expect(
        find.byType(DkSegmented<DkShapeKind>).evaluate().length +
            find.byType(DkSegmented<DkEraserMode>).evaluate().length,
        segmented ? 1 : 0,
      );
      expect(
        find.byKey(const Key('colours')),
        colours ? findsOne : findsNothing,
      );
      expect(
        find.byType(DkStrokePreview),
        sliders > 0 ? findsOne : findsNothing,
      );
    }
  });

  testWidgets('changes apply at once: font size, shape, eraser mode', (
    tester,
  ) async {
    final changes = <DkToolOptions>[];
    await tester.pumpWidget(app(sheet(DkMarkupKind.text, changes)));
    await tester.tap(find.bySemanticsLabel('Increase'));
    expect(changes.last.fontSize, 15);
    await tester.pumpWidget(app(sheet(DkMarkupKind.shape, changes)));
    await tester.tap(find.text('Arrow'));
    expect(changes.last.shape, DkShapeKind.arrow);
    await tester.pumpWidget(app(sheet(DkMarkupKind.eraser, changes)));
    await tester.tap(find.text('Stroke'));
    expect(changes.last.eraser, DkEraserMode.stroke);
  });

  testWidgets('the stroke preview is 120 × 24 and decorative', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(sheet(DkMarkupKind.pen, [])));
    expect(tester.getSize(find.byType(DkStrokePreview)), DkStrokePreview.size);
    expect(find.text('3 pt'), findsOne);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('German labels', (tester) async {
    await tester.pumpWidget(
      app(sheet(DkMarkupKind.highlighter, []), locale: const Locale('de')),
    );
    expect(find.text('Stärke'), findsOne);
    expect(find.text('Deckkraft'), findsOne);
  });
}
