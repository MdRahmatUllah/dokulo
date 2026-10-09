import 'dart:io';

import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/screens/files/trash_screen.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'files_screen_test.dart' show FilesFixture, pumpFiles, settle;

void main() {
  late FilesFixture f;
  setUp(() async {
    f = FilesFixture();
    await f.setUp();
  });
  tearDown(() => f.tearDown());

  /// Two files in the trash: Scan.pdf (2 days ago), Draft.pdf (26 days ago).
  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    final now = DateTime.now();
    for (final (name, ago) in [('Scan.pdf', 2), ('Draft.pdf', 26)]) {
      final pdf = File('${f.root.path}/Dokulo/$name')
        ..createSync(recursive: true)
        ..writeAsStringSync('%PDF');
      final id = await f.db
          .into(f.db.files)
          .insert(
            FilesCompanion.insert(
              path: pdf.path,
              name: name,
              size: 4,
              created: DateTime(2026, 10, 1),
              modified: DateTime(2026, 10, 1),
            ),
          );
      await f.store.trashFile(f.db, id, now: now.subtract(Duration(days: ago)));
    }
  });

  Future<void> tapReal(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await settle(tester);
  }

  testWidgets('rows show the days left, the banner the retention', (
    tester,
  ) async {
    await seed(tester);
    await pumpFiles(tester, f, location: Routes.trash);
    expect(find.text('Files are deleted for good after 30 days.'), findsOne);
    expect(find.text('4 B · 28 days left'), findsOneWidget);
    expect(find.text('4 B · 4 days left'), findsOneWidget);
  });

  testWidgets('the restore button takes a file back to Files', (tester) async {
    await seed(tester);
    await pumpFiles(tester, f, location: Routes.trash);
    await tapReal(tester, find.bySemanticsLabel('Restore').first);
    expect(find.text('Scan.pdf'), findsNothing);
    expect(
      await tester.runAsync(() => f.db.select(f.db.trash).get()),
      hasLength(1),
    );
  });

  testWidgets('Delete for good asks, then removes the file from disk', (
    tester,
  ) async {
    await seed(tester);
    await pumpFiles(tester, f, location: Routes.trash);
    await tester.tap(find.text('Draft.pdf'));
    await settle(tester);
    await tester.tap(find.text('Delete for good'));
    await settle(tester);
    expect(find.text('Delete this file for good?'), findsOneWidget);
    await tapReal(tester, find.text('Delete for good').last);
    expect(find.text('Draft.pdf'), findsNothing);
    expect(File('${f.root.path}/Dokulo/Draft.pdf').existsSync(), isFalse);
  });

  testWidgets('Empty asks for every file, then shows ILL-08', (tester) async {
    await seed(tester);
    await pumpFiles(tester, f, location: Routes.trash);
    await tester.tap(find.text('Empty'));
    await settle(tester);
    expect(find.text('Delete 2 files for good?'), findsOneWidget);
    expect(find.text("This can't be undone."), findsOneWidget);
    await tapReal(tester, find.text('Delete for good'));
    expect(find.text('Nothing here'), findsOneWidget);
    expect(await tester.runAsync(() => f.db.select(f.db.files).get()), isEmpty);
  });

  testWidgets('7-day retention: the banner and the rows say so', (
    tester,
  ) async {
    f.prefs['trash.days'] = 7;
    await seed(tester);
    await pumpFiles(tester, f, location: Routes.trash);
    expect(find.text('Files are deleted for good after 7 days.'), findsOne);
    expect(find.text('4 B · 5 days left'), findsOneWidget);
    expect(find.text('4 B · 0 days left'), findsOneWidget);
  });

  test('daysLeft rounds up and stops at 0', () {
    final now = DateTime(2026, 10, 9, 12);
    expect(daysLeft(now, 30, now: now), 30);
    expect(daysLeft(now.subtract(const Duration(hours: 1)), 30, now: now), 30);
    expect(daysLeft(now.subtract(const Duration(days: 29)), 30, now: now), 1);
    expect(daysLeft(now.subtract(const Duration(days: 40)), 30, now: now), 0);
  });
}
