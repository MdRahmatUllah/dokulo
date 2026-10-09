import 'package:app_pdf/components/dk_page_chip.dart';
import 'package:app_pdf/providers/files_providers.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'files_screen_test.dart' show FilesFixture, pumpFiles, settle;

void main() {
  late FilesFixture f;
  setUp(() async {
    f = FilesFixture();
    await f.setUp();
  });
  tearDown(() => f.tearDown());

  /// "Mietvertrag Musterstraße.pdf" by name; "Bescheid.pdf" holds the word
  /// on page 2; "Scan.pdf" has no text layer.
  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    await f.file('Mietvertrag Musterstraße.pdf');
    final bescheid = await f.file('Bescheid.pdf', pages: 4);
    await f.file('Scan.pdf', pages: 3);
    await f.db.customInsert(
      'INSERT INTO ocr_text (file_id, page, page_text) VALUES (?, ?, ?)',
      variables: [
        Variable(bescheid),
        Variable(2),
        Variable('Aufwendungen laut Mietvertrag werden anerkannt'),
      ],
    );
    await (f.db.update(f.db.files)..where((r) => r.id.equals(bescheid))).write(
      const FilesCompanion(hasText: Value(true)),
    );
  });

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(EditableText), text);
    await settle(tester);
  }

  testWidgets('names and text inside files, grouped', (tester) async {
    await seed(tester);
    await pumpFiles(tester, f);
    await type(tester, 'mietver');
    expect(find.text('Names'), findsOneWidget);
    expect(find.text('Text inside files'), findsOneWidget);
    expect(find.text('Bescheid.pdf'), findsOneWidget);
    // The special rows and the folder lists step aside.
    expect(find.text('Recently deleted'), findsNothing);
    final chip = tester.widget<DkPageChip>(find.byType(DkPageChip));
    expect(chip.page, 2);
    // Two files have no text layer (Mietvertrag's and Scan.pdf).
    expect(find.text('2 scans have no searchable text yet.'), findsOneWidget);
  });

  testWidgets('a text hit opens V1 at its page', (tester) async {
    await seed(tester);
    final router = await pumpFiles(tester, f);
    await type(tester, 'anerkannt');
    await tester.tap(find.byType(DkPageChip));
    await settle(tester);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      endsWith('?page=2'),
    );
  });

  testWidgets('nothing found: ILL-07 with the query; Cancel clears', (
    tester,
  ) async {
    await seed(tester);
    await pumpFiles(tester, f);
    await type(tester, 'Kaution');
    expect(find.text('Nothing found for “Kaution”'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Recently deleted'), findsOneWidget);
  });

  test('ftsQuery quotes each word as a prefix', () {
    expect(ftsQuery('miet vertrag'), '"miet"* "vertrag"*');
    expect(ftsQuery(' a"b  '), '"a""b"*');
    expect(ftsQuery('  '), '');
  });
}
