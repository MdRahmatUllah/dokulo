import 'package:app_pdf/catalogue/bar_states.dart';
import 'package:app_pdf/components/dk_editor_bars.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Widget home, {
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
    child: Scaffold(body: home),
  ),
);

void main() {
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('strip and markup bar, $name, ${(scale * 100).round()} %', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(393, 320);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(const EditorBarStates(), tokens: tokens, textScale: scale),
        );
        await expectLater(
          find.byType(EditorBarStates),
          matchesGoldenFile(
            'goldens/editor_bars_${name}_${(scale * 100).round()}.png',
          ),
        );
      });
    }
  }

  testWidgets('strip: 64 tall, selecting a tool, undo works and redo is off', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final picked = <int>[];
    var undos = 0;
    await tester.pumpWidget(
      app(
        Align(
          alignment: Alignment.bottomCenter,
          child: DkToolStrip(
            tools: EditorBarStates.tools,
            selected: 1,
            onSelect: picked.add,
            onUndo: () => undos++,
            onRedo: null,
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(DkToolStrip)).height, 64);
    await tester.tap(find.text('Highlighter'));
    await tester.tap(find.byTooltip('Undo'));
    await tester.tap(find.byTooltip('Redo'));
    expect(picked, [2]);
    expect(undos, 1);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Pen')),
      isSemantics(label: 'Pen', isSelected: true, isButton: true),
    );
    handle.dispose();
  });

  testWidgets('markup bar: 8 above the selection, below near the top; '
      'actions, labels in EN and DE', (tester) async {
    tester.view.physicalSize = const Size(393, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final (locale, underline, ask) in [
      (const Locale('en'), 'Underline', 'Ask AI'),
      (const Locale('de'), 'Unterstreichen', 'KI fragen'),
    ]) {
      final handle = tester.ensureSemantics();
      final done = <DkMarkupAction>[];
      const selection = Rect.fromLTWH(100, 300, 150, 20);
      await tester.pumpWidget(
        app(
          Stack(
            children: [
              DkMarkupBar.over(selection: selection, onAction: done.add),
            ],
          ),
          locale: locale,
        ),
      );
      final bar = tester.getRect(find.byType(DkMarkupBar));
      expect(bar.bottom, selection.top - 8);
      expect(bar.height, 44);
      await tester.tap(find.bySemanticsLabel(underline));
      await tester.tap(find.bySemanticsLabel(ask));
      expect(done, [DkMarkupAction.underline, DkMarkupAction.ask]);
      handle.dispose();
    }
    const top = Rect.fromLTWH(100, 10, 150, 20);
    await tester.pumpWidget(
      app(
        Stack(
          children: [DkMarkupBar.over(selection: top, onAction: (_) {})],
        ),
      ),
    );
    expect(tester.getRect(find.byType(DkMarkupBar)).top, top.bottom + 8);
  });

  testWidgets('markup bar: labels where they fit, icons alone where not', (
    tester,
  ) async {
    for (final (width, labels) in [(1024.0, true), (393.0, false)]) {
      tester.view.physicalSize = Size(width, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          Stack(
            children: [
              DkMarkupBar.over(
                selection: Rect.fromLTWH(width / 2 - 50, 200, 100, 20),
                onAction: (_) {},
              ),
            ],
          ),
        ),
      );
      expect(find.text('Copy').evaluate().isNotEmpty, labels, reason: '$width');
    }
  });
}
