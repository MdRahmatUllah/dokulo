import 'package:app_pdf/providers/files_providers.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_providers.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'files_screen_test.dart' show FilesFixture, cardMore, pumpFiles, settle;

/// Favourites (DK-0280): from the file sheet, a section at the top of F1,
/// first in T2's picker.
void main() {
  late FilesFixture f;
  setUp(() async {
    f = FilesFixture();
    await f.setUp();
  });
  tearDown(() => f.tearDown());

  Future<void> sheetTap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text(label));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await settle(tester);
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(cardMore);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('mark a favourite: its section on top; unmark: gone', (
    tester,
  ) async {
    await tester.runAsync(() => f.file('Vertrag.pdf'));
    await pumpFiles(tester, f);
    expect(find.text('Favourites'), findsNothing);
    await openSheet(tester);
    await sheetTap(tester, 'Add to favourites');
    expect(find.text('Favourites'), findsOneWidget);
    expect(find.text('Vertrag.pdf'), findsNWidgets(2)); // and in Files
    await openSheet(tester);
    await sheetTap(tester, 'Remove from favourites');
    expect(find.text('Favourites'), findsNothing);
  });

  testWidgets('T2 offers favourites first', (tester) async {
    late int older;
    await tester.runAsync(() async {
      older = await f.file('Old.pdf', modified: DateTime(2026, 1, 1));
      await f.file('New.pdf', modified: DateTime(2026, 10, 1));
      await setFavourite(f.db, older, true);
    });
    await pumpFiles(tester, f);
    final container = ProviderScope.containerOf(
      tester.element(find.text('New.pdf').first),
    );
    final picked = await tester.runAsync(
      () => container.read(recentCompatibleFilesProvider('compress').future),
    );
    expect(picked!.map((e) => e.name), ['Old.pdf', 'New.pdf']);
  });

  testWidgets('a deleted favourite leaves the section', (tester) async {
    await tester.runAsync(() async {
      final id = await f.file('Gone.pdf');
      await setFavourite(f.db, id, true);
      await f.db
          .into(f.db.trash)
          .insert(
            TrashCompanion.insert(fileId: Value(id), deletedAt: DateTime(2026)),
          );
    });
    await pumpFiles(tester, f);
    expect(find.text('Favourites'), findsNothing);
  });
}
