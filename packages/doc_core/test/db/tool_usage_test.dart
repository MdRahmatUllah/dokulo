import 'package:doc_core/doc_core.dart';
import 'package:test/test.dart';

void main() {
  late DokuloDatabase db;
  setUp(() => db = DokuloDatabase.memory());
  tearDown(() => db.close());

  test(
    'each run counts; suggestions are the most used, newest first on a tie',
    () async {
      final t0 = DateTime(2026, 10, 7, 9);
      Future<void> run(String tool, int minute) =>
          db.recordToolRun(tool, t0.add(Duration(minutes: minute)));

      await run('compress', 0);
      await run('merge', 1);
      await run('compress', 2);
      await run('ocr', 3);
      await run('merge', 4);
      await run('split', 5);

      final rows = await db.select(db.toolUsage).get();
      final compress = rows.singleWhere((r) => r.toolId == 'compress');
      expect(compress.count, 2);
      expect(compress.lastUsed, t0.add(const Duration(minutes: 2)));

      // compress and merge both ran twice; merge more recently.
      expect(await db.mostUsedTools(3).get(), ['merge', 'compress', 'split']);
      expect(await db.lastUsedTool().getSingleOrNull(), 'split');
    },
  );

  test('nothing recorded: no suggestions and no last tool', () async {
    expect(await db.mostUsedTools(4).get(), isEmpty);
    expect(await db.lastUsedTool().getSingleOrNull(), isNull);
  });
}
