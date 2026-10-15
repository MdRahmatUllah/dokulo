import 'package:app_pdf/components/dk_file_card.dart';
import 'package:app_pdf/components/dk_tool_tile.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_screen_test.dart' show addFile, pumpHome;

/// H1 on tablets (DK-0649; UI spec §30).
void main() {
  late DokuloDatabase db;
  setUp(() => db = DokuloDatabase.memory());
  tearDown(() => db.close());

  Future<void> six(WidgetTester tester) => tester.runAsync(() async {
    for (var i = 0; i < 6; i++) {
      await addFile(db, 'f$i.pdf', opened: DateTime(2026, 10, 1, i));
    }
  });

  /// How many items share the first row's top.
  int firstRow(WidgetTester tester, Finder items) {
    final tops = [
      for (final e in items.evaluate())
        tester.getTopLeft(find.byWidget(e.widget)).dy,
    ];
    return tops.where((y) => y == tops.first).length;
  }

  testWidgets('portrait (820): tools 6 across, Recent in 2 columns', (
    tester,
  ) async {
    await six(tester);
    await pumpHome(tester, db, size: const Size(820, 1180));
    expect(firstRow(tester, find.byType(DkToolTile)), 6);
    expect(firstRow(tester, find.byType(DkFileCard)), 2);
  });

  testWidgets('landscape (1366): tools 8 across; Recent in a 360 column', (
    tester,
  ) async {
    await six(tester);
    await pumpHome(tester, db, size: const Size(1366, 1024));
    expect(firstRow(tester, find.byType(DkToolTile)), 8);
    final card = find.byType(DkFileCard).first;
    expect(tester.getSize(card).width, 360);
    expect(tester.getTopRight(card).dx, 1366);
  });

  testWidgets('rotation keeps the state: edit mode survives', (tester) async {
    await six(tester);
    await pumpHome(tester, db, size: const Size(820, 1180));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
    tester.view.physicalSize = const Size(1180, 820);
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
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
        await six(tester);
        await pumpHome(tester, db, tokens: tokens, size: size);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/home_tablet_${name}_$theme.png'),
        );
      });
    }
  }
}
