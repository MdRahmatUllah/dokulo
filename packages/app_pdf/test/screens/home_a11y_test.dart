import 'package:app_pdf/components/dk_tool_tile.dart';
import 'package:app_pdf/screens/home/home_screen.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_screen_test.dart' show pumpHome;

/// H1 at 200 % text and its screen-reader order (DK-0254).
void main() {
  late DokuloDatabase db;
  setUp(() => db = DokuloDatabase.memory());
  tearDown(() => db.close());

  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    final today = DateTime.now();
    final at = DateTime(today.year, today.month, today.day, 14, 32);
    final id = await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            path: '/x/Mietvertrag.pdf',
            name: 'Mietvertrag.pdf',
            size: 186000,
            pages: const Value(2),
            created: at,
            modified: at,
          ),
        );
    await db
        .into(db.recents)
        .insert(RecentsCompanion.insert(fileId: Value(id), openedAt: at));
  });

  testWidgets('200 %: the pinned grid is 2 across and nothing overflows', (
    tester,
  ) async {
    await seed(tester);
    await pumpHome(tester, db, textScale: 2);
    final tiles = tester.widgetList(find.byType(DkToolTile)).toList();
    expect(tiles, isNotEmpty);
    final first = tester.getRect(find.byType(DkToolTile).at(0));
    final second = tester.getRect(find.byType(DkToolTile).at(1));
    final third = tester.getRect(find.byType(DkToolTile).at(2));
    expect(second.top, first.top, reason: 'two on the first row');
    expect(third.top, greaterThan(first.top), reason: 'the third wraps');
    expect(tester.takeException(), isNull, reason: 'no overflow');
  });

  for (final (name, locale) in [
    ('en', const Locale('en')),
    ('de', const Locale('de')),
  ]) {
    testWidgets('golden at 200 %, $name', (tester) async {
      await seed(tester);
      await pumpHome(tester, db, textScale: 2, locale: locale);
      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_200_$name.png'),
      );
    });
  }

  testWidgets('screen-reader order: title, privacy, tools, Open, Recent', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await seed(tester);
    await pumpHome(tester, db);
    final tree = tester
        .getSemantics(find.byType(HomeScreen))
        .toStringDeep(childOrder: DebugSemanticsDumpOrder.traversalOrder);
    final order = [
      'Dokulo',
      'Everything stays on this phone',
      'Your tools',
      'Merge PDF',
      'Black out (redact)',
      'Open a file',
      'Recent',
      'Mietvertrag.pdf',
    ];
    final at = [for (final s in order) tree.indexOf(s)];
    expect(at, everyElement(greaterThanOrEqualTo(0)), reason: '$at');
    expect(at, orderedEquals([...at]..sort()), reason: '$order\n$at');
    // A Pro tile says so.
    expect(tree, contains('Black out (redact), Pro'));
    handle.dispose();
  });
}
