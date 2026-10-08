import 'package:app_pdf/catalogue/detection_states.dart';
import 'package:app_pdf/components/dk_detection_group.dart';
import 'package:app_pdf/components/dk_page_chip.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'a11y.dart';

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

void phone(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const items = [
  DkDetection(preview: 'DE00 •••• 0000', page: 1, checked: true),
  DkDetection(preview: 'DE00 •••• 0001', page: 3, checked: false),
];

Widget group({
  List<DkDetection> items = items,
  bool expanded = true,
  ValueChanged<bool>? onExpanded,
  ValueChanged<bool>? onCheckedAll,
  void Function(int, bool)? onChecked,
  ValueChanged<int>? onPage,
}) => DkDetectionGroup(
  icon: DetectionGroupStates.iban,
  name: 'IBAN',
  items: items,
  expanded: expanded,
  onExpanded: onExpanded ?? (_) {},
  onCheckedAll: onCheckedAll ?? (_) {},
  onChecked: onChecked ?? (_, _) {},
  onPage: onPage ?? (_) {},
);

void main() {
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
      final file = 'detection_group_${name}_${lang}_${(scale * 100).round()}';
      testWidgets('golden: $file', (tester) async {
        phone(tester, Size(393, scale > 1 ? 900 : 520));
        await tester.pumpWidget(
          app(
            const DetectionGroupStates(),
            tokens: tokens,
            scale: scale,
            locale: Locale(lang),
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(DetectionGroupStates),
          matchesGoldenFile('goldens/$file.png'),
        );
      });
    }
  }

  testWidgets('the category checkbox: a dash when some are on; all on, then '
      'all off', (tester) async {
    phone(tester, const Size(393, 600));
    final all = <bool>[];
    await tester.pumpWidget(app(group(onCheckedAll: all.add)));
    Checkbox head() => tester.widget<Checkbox>(find.byType(Checkbox).first);
    expect(head().value, isNull);
    await tester.tap(find.byType(Checkbox).first);
    expect(all, [true]);
    await tester.pumpWidget(
      app(
        group(
          items: [
            for (final i in items)
              DkDetection(preview: i.preview, page: i.page, checked: true),
          ],
          onCheckedAll: all.add,
        ),
      ),
    );
    expect(head().value, isTrue);
    await tester.tap(find.byType(Checkbox).first);
    expect(all, [true, false]);
  });

  testWidgets('the row opens and closes the list; an item toggles; its page '
      'chip jumps', (tester) async {
    phone(tester, const Size(393, 600));
    final opened = <bool>[], checked = <(int, bool)>[], pages = <int>[];
    await tester.pumpWidget(
      app(
        group(
          expanded: false,
          onExpanded: opened.add,
          onChecked: (i, v) => checked.add((i, v)),
          onPage: pages.add,
        ),
      ),
    );
    expect(find.text('DE00 •••• 0000'), findsNothing);
    await tester.tap(find.text('IBAN'));
    expect(opened, [true]);
    await tester.pumpWidget(
      app(
        group(
          onExpanded: opened.add,
          onChecked: (i, v) => checked.add((i, v)),
          onPage: pages.add,
        ),
      ),
    );
    await tester.tap(find.text('DE00 •••• 0001'));
    expect(checked, [(1, true)]);
    await tester.tap(find.byType(DkPageChip).last);
    expect(pages, [3]);
    await tester.tap(find.text('IBAN'));
    expect(opened, [true, false]);
  });

  testWidgets('no onExpanded: no chevron and no list', (tester) async {
    phone(tester, const Size(393, 600));
    await tester.pumpWidget(
      app(
        DkDetectionGroup(
          icon: DetectionGroupStates.person,
          name: 'Names',
          items: items,
          expanded: true,
          onCheckedAll: (_) {},
          onChecked: (_, _) {},
          onPage: (_) {},
        ),
      ),
    );
    expect(find.text('DE00 •••• 0000'), findsNothing);
    expect(find.text('2'), findsOne);
  });

  testWidgets('screen readers and the keyboard', (tester) async {
    phone(tester, const Size(393, 600));
    final handle = tester.ensureSemantics();
    final all = <bool>[], opened = <bool>[];
    await tester.pumpWidget(
      app(group(onCheckedAll: all.add, onExpanded: opened.add)),
    );
    // The category: a checkbox named after it, and the row that opens it.
    expect(
      tester.getSemantics(find.bySemanticsLabel('IBAN')),
      isSemantics(hasCheckedState: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('IBAN, 2')),
      isSemantics(isButton: true, hasExpandedState: true, isExpanded: true),
    );
    expectPressableButtons(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    // Tab reaches the category's checkbox first, then the row.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(all, [true]);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened, [false]);
    handle.dispose();
  });
}
