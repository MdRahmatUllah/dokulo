import 'package:app_pdf/catalogue/choice_row_states.dart';
import 'package:app_pdf/components/dk_count_badge.dart';
import 'package:app_pdf/components/dk_checkbox_row.dart';
import 'package:app_pdf/components/dk_radio_row.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child, {DkTokens? tokens, double scale = 1}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
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

void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final scale in [1.0, 2.0]) {
      final name = '${theme}_${(scale * 100).round()}';
      testWidgets('golden: $name', (tester) async {
        tester.view.physicalSize = Size(393, scale > 1 ? 780 : 470);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            const SingleChildScrollView(child: DkChoiceRowsGallery()),
            tokens: tokens,
            scale: scale,
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/dk_choice_rows_$name.png'),
        );
      });
    }
  }

  testWidgets('DkRadioRow: the whole row selects, as one node', (tester) async {
    final handle = tester.ensureSemantics();
    int? picked;
    await tester.pumpWidget(
      app(
        RadioGroup<int>(
          groupValue: 0,
          onChanged: (v) => picked = v,
          child: const Column(
            children: [
              DkRadioRow(value: 0, label: 'Both sides'),
              DkRadioRow(value: 1, label: 'Front only', description: 'Faster'),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Faster'));
    expect(picked, 1);
    expect(
      tester.getSize(find.byType(DkRadioRow<int>).first).height,
      greaterThanOrEqualTo(48),
    );
    final node = tester.getSemantics(find.text('Front only'));
    expect(node.label, contains('Front only'));
    expect(node.label, contains('Faster'));
    expect(node, isSemantics(hasCheckedState: true, isChecked: false));
    handle.dispose();
  });

  testWidgets('DkCheckboxRow: the whole row toggles; count badge; disabled', (
    tester,
  ) async {
    var on = false;
    await tester.pumpWidget(
      app(
        Column(
          children: [
            StatefulBuilder(
              builder: (context, set) => DkCheckboxRow(
                label: 'IBAN',
                value: on,
                count: 3,
                onChanged: (v) => set(() => on = v),
              ),
            ),
            const DkCheckboxRow(label: 'Emails', value: false, onChanged: null),
          ],
        ),
      ),
    );
    // Unchecked: the count badge is muted (the export's `.cb` on `--ic2`).
    expect(
      tester.widget<DkCountBadge>(find.byType(DkCountBadge)).muted,
      isTrue,
    );
    await tester.tap(find.text('IBAN'));
    await tester.pump();
    expect(on, isTrue);
    expect(find.text('3'), findsOneWidget);
    expect(
      tester.widget<DkCountBadge>(find.byType(DkCountBadge)).muted,
      isFalse,
    );
    expect(
      tester.getSize(find.byType(DkCheckboxRow).first).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('Emails'));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).last).value, isFalse);
  });

  testWidgets(
    'keyboard: Tab focuses the row, Space toggles; disabled skipped',
    (tester) async {
      var on = false;
      int? picked;
      await tester.pumpWidget(
        app(
          Column(
            children: [
              StatefulBuilder(
                builder: (context, set) => DkCheckboxRow(
                  label: 'IBAN',
                  value: on,
                  onChanged: (v) => set(() => on = v),
                ),
              ),
              RadioGroup<int>(
                groupValue: 0,
                onChanged: (v) => picked = v,
                child: const Column(
                  children: [
                    DkRadioRow(value: 1, label: 'Off', enabled: false),
                    DkRadioRow(value: 2, label: 'Back only'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(on, isTrue);
      // The checkbox itself takes no focus, and the disabled row is skipped.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(picked, 2);
      await tester.tap(find.text('Off'));
      expect(picked, 2);
    },
  );
}
