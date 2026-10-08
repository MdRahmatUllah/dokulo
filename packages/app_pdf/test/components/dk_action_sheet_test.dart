import 'package:app_pdf/catalogue/overlay_states.dart';
import 'package:app_pdf/components/dk_action_sheet.dart';
import 'package:app_pdf/components/dk_icon.dart';
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

void main() {
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('the action sheet, $name, ${(scale * 100).round()} %', (
        tester,
      ) async {
        tester.view.physicalSize = Size(393, scale == 1 ? 520 : 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(const ActionSheetStates(), tokens: tokens, textScale: scale),
        );
        await expectLater(
          find.byType(ActionSheetStates),
          matchesGoldenFile(
            'goldens/action_sheet_${name}_${(scale * 100).round()}.png',
          ),
        );
      });
    }
  }

  testWidgets('destructive rows go last, in danger; rows are 48 tall', (
    tester,
  ) async {
    await tester.pumpWidget(app(const ActionSheetStates()));
    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where(
          (s) => const [
            'Compress PDF',
            'Rename',
            'Move',
            'Info',
            'Delete',
          ].contains(s),
        )
        .toList();
    expect(labels, ['Compress PDF', 'Rename', 'Move', 'Info', 'Delete']);
    final delete = tester.widget<Text>(find.text('Delete'));
    expect(delete.style!.color, DkTokens.light.color.danger);
    expect(
      tester
          .getSize(
            find.ancestor(
              of: find.text('Rename'),
              matching: find.byType(InkWell),
            ),
          )
          .height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('a row closes the sheet, then runs its action', (tester) async {
    final done = <String>[];
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDkActionSheet(
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
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(done, ['rename']);
    expect(find.byType(DkActionSheet), findsNothing);
  });

  testWidgets('screen readers hear each row as a button', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(const ActionSheetStates()));
    expect(
      tester.getSemantics(find.text('Delete')),
      isSemantics(label: 'Delete', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });
}
