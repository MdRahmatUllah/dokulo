import 'package:app_pdf/catalogue/overlay_states.dart';
import 'package:app_pdf/components/dk_action_sheet.dart';
import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/components/dk_menu.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child, {DkTokens? tokens, double textScale = 1}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dokuloTheme(tokens ?? DkTokens.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(body: child),
      ),
    );

/// A button at [at] that opens the menu.
Widget anchorAt(Alignment at, List<String> done) => Align(
  alignment: at,
  child: Builder(
    builder: (context) => TextButton(
      onPressed: () => showDkMenu(
        context,
        groups: [
          [
            DkAction(
              icon: DkIcons.rename,
              label: 'Rename',
              onTap: () => done.add('rename'),
            ),
          ],
        ],
      ),
      child: const Text('more'),
    ),
  ),
);

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('the menu, $name, ${(scale * 100).round()} %', (
        tester,
      ) async {
        tester.view.physicalSize = Size(393, scale == 1 ? 260 : 420);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(const MenuStates(), tokens: tokens, textScale: scale),
        );
        await expectLater(
          find.byType(DkMenu),
          matchesGoldenFile(
            'goldens/menu_${name}_${(scale * 100).round()}.png',
          ),
        );
      });
    }
  }

  testWidgets('232 wide at least; 44 rows; the chosen option is selected', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(const MenuStates()));
    final menu = tester.getSize(find.byType(DkMenu));
    expect(menu.width, greaterThanOrEqualTo(232));
    final row = find.ancestor(
      of: find.text('Date'),
      matching: find.byType(DkActionRow),
    );
    expect(tester.getSize(row).height, 44);
    expect(
      tester.getSemantics(find.text('Name')),
      isSemantics(label: 'Name', isButton: true, isSelected: true),
    );
    handle.dispose();
  });

  testWidgets('opens under a top-right button, right-aligned; a row closes '
      'it and runs', (tester) async {
    phone(tester);
    final done = <String>[];
    await tester.pumpWidget(app(anchorAt(Alignment.topRight, done)));
    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();
    final button = tester.getRect(find.text('more').first);
    final menu = tester.getRect(find.byType(DkMenu));
    expect(menu.top, greaterThan(button.bottom));
    expect(menu.right, lessThanOrEqualTo(393 - 8));
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(done, ['rename']);
    expect(find.byType(DkMenu), findsNothing);
  });

  testWidgets('near the bottom it opens above; a tap outside closes it', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(app(anchorAt(Alignment.bottomLeft, [])));
    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();
    final button = tester.getRect(find.text('more').first);
    final menu = tester.getRect(find.byType(DkMenu));
    expect(menu.bottom, lessThan(button.top));
    expect(menu.left, greaterThanOrEqualTo(8));
    await tester.tapAt(const Offset(300, 100));
    await tester.pumpAndSettle();
    expect(find.byType(DkMenu), findsNothing);
  });
}
