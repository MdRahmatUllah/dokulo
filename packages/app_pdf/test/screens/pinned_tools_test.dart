import 'package:app_pdf/components/dk_pro_badge.dart';
import 'package:app_pdf/components/dk_sheet.dart';
import 'package:app_pdf/components/dk_tool_tile.dart';
import 'package:app_pdf/providers/files_providers.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/tools/tool_catalogue.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_screen_test.dart' show pumpHome, settle;

/// Home's pinned tools (DK-0244, DK-0248, DK-0249).
void main() {
  late DokuloDatabase db;
  setUp(() => db = DokuloDatabase.memory());
  tearDown(() => db.close());

  List<String> tiles(WidgetTester tester) => [
    for (final t in tester.widgetList<DkToolTile>(find.byType(DkToolTile)))
      t.toolId,
  ];

  Future<void> real(WidgetTester tester, Future<void> Function() action) async {
    await tester.runAsync(() async {
      await action();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);
  }

  testWidgets('first launch: the eight defaults, in order; never Scan', (
    tester,
  ) async {
    await pumpHome(tester, db);
    expect(tiles(tester), defaultPinnedTools);
    expect(tiles(tester), isNot(contains('scan')));
  });

  testWidgets('a Pro tile has the badge, is never greyed, and opens T2', (
    tester,
  ) async {
    final router = await pumpHome(tester, db);
    final pro = [
      for (final id in defaultPinnedTools)
        if (ToolCatalogue.of(id).isPro) id,
    ];
    expect(pro, isNotEmpty);
    final tile = find.byWidgetPredicate(
      (w) => w is DkToolTile && w.toolId == pro.first,
    );
    expect(
      find.descendant(of: tile, matching: find.byType(DkProBadge)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: tile, matching: find.byType(Opacity)),
      findsNothing,
      reason: 'never greyed',
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), Routes.tool(pro.first));
  });

  testWidgets('long-press: Unpin, and Undo puts it back in its place', (
    tester,
  ) async {
    await pumpHome(tester, db);
    await tester.longPress(find.text('Sign PDF'));
    await tester.pumpAndSettle();
    expect(find.text('About this tool'), findsOneWidget);
    await real(tester, () => tester.tap(find.text('Unpin')));
    expect(tiles(tester), isNot(contains('sign')));
    expect(find.text('Unpinned Sign PDF'), findsOneWidget);
    await real(tester, () => tester.tap(find.text('Undo')));
    expect(tiles(tester), defaultPinnedTools);
  });

  testWidgets('edit: the minus unpins; Add tool appears and adds', (
    tester,
  ) async {
    await pumpHome(tester, db);
    expect(find.text('Add tool'), findsNothing);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Add tool'), findsNothing, reason: '8 pinned: no room');
    await real(
      tester,
      () => tester.tap(find.bySemanticsLabel('Unpin Merge PDF')),
    );
    expect(tiles(tester), isNot(contains('merge')));
    expect(find.text('Add tool'), findsOneWidget);
    await tester.tap(find.text('Add tool'));
    await tester.pumpAndSettle();
    expect(find.text('Add a tool'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DkSheet),
        matching: find.text('Compress PDF'),
      ),
      findsNothing,
      reason: 'pinned already',
    );
    await real(tester, () => tester.tap(find.text('Rotate PDF')));
    expect(tiles(tester).last, 'rotate');
    expect(find.text('Add tool'), findsNothing, reason: '8 again');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('edit: drag a tile onto another to move it there', (
    tester,
  ) async {
    await pumpHome(tester, db);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    final from = tester.getCenter(find.text('Summarize'));
    final to = tester.getCenter(find.text('Merge PDF'));
    await real(tester, () async {
      final g = await tester.startGesture(from);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      await g.moveTo(to);
      await tester.pump();
      await g.up();
    });
    expect(tiles(tester).first, 'summarize');
  });

  testWidgets('unpinning all stays empty: no defaults again', (tester) async {
    await tester.runAsync(() => savePinnedTools(db, const []));
    await pumpHome(tester, db);
    expect(tiles(tester), isEmpty);
  });
}
