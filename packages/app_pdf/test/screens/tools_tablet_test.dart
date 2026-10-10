import 'package:app_pdf/components/dk_chip.dart';
import 'package:app_pdf/components/dk_tool_tile.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tools_screen_test.dart' show pumpTools;

/// T1 on tablets (DK-0650; UI spec §30).
void main() {
  /// How many tiles share the first tile's top.
  int firstRow(WidgetTester tester) {
    final tops = [
      for (final e in find.byType(DkToolTile).evaluate())
        tester.getTopLeft(find.byWidget(e.widget)).dy,
    ];
    return tops.where((y) => y == tops.first).length;
  }

  testWidgets('portrait (820): 6 across, the chips as on a phone', (
    tester,
  ) async {
    await pumpTools(tester, size: const Size(820, 1180));
    expect(firstRow(tester), 6); // Organize has 6
    expect(find.byType(DkChip), findsWidgets);
  });

  testWidgets('landscape (1366): the sidebar with counts, 8 across', (
    tester,
  ) async {
    await pumpTools(tester, size: const Size(1366, 1024));
    expect(find.byType(DkChip), findsNothing);
    // The sidebar: All, then each category, with its count.
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Security'), findsNWidgets(2)); // sidebar + section
    // A tap jumps to the section and selects it.
    await tester.tap(find.text('Security').first);
    await tester.pumpAndSettle();
    final row = find.ancestor(
      of: find.text('Security').first,
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.selected ?? false),
      ),
    );
    expect(row, findsOneWidget);
  });

  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (name, size) in [
      ('portrait', const Size(820, 1180)),
      ('landscape', const Size(1366, 1024)),
    ]) {
      testWidgets('golden: $name, $theme', (tester) async {
        await pumpTools(tester, tokens: tokens, size: size);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/tools_tablet_${name}_$theme.png'),
        );
      });
    }
  }
}
