import 'dart:io';

import 'package:app_pdf/l10n/formats.dart';
import 'package:app_pdf/providers/files_providers.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'files_screen_test.dart' show FilesFixture, cardMore, pumpFiles, settle;

/// Info (DK-0275), from the file sheet.
void main() {
  late FilesFixture f;
  setUp(() async {
    f = FilesFixture();
    await f.setUp();
  });
  tearDown(() => f.tearDown());

  Future<void> realTap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    // The header read and the versions list are real disk round trips.
    for (var i = 0; i < 3; i++) {
      await settle(tester);
    }
  }

  Future<int> seed(
    WidgetTester tester, {
    Directory? folderDir,
    int? folder,
  }) async => (await tester.runAsync(() async {
    final dir = folderDir ?? Directory('${f.root.path}/Dokulo');
    final pdf = File('${dir.path}/Vertrag.pdf')
      ..createSync(recursive: true)
      ..writeAsStringSync('%PDF-1.7\n%stuff');
    return f.db
        .into(f.db.files)
        .insert(
          FilesCompanion.insert(
            path: pdf.path,
            name: 'Vertrag.pdf',
            size: 2400000,
            pages: const Value(12),
            created: DateTime(2026, 10, 2, 9, 12),
            modified: DateTime(2026, 10, 2, 9, 12),
            folderId: Value(folder),
          ),
        );
  }))!;

  testWidgets('the rows: location, size, pages, PDF version, password, text', (
    tester,
  ) async {
    late int apartment;
    await tester.runAsync(() async {
      apartment = await f.store.createFolder(f.db, 'Apartment');
    });
    await seed(
      tester,
      folderDir: Directory('${f.root.path}/Dokulo/Apartment'),
      folder: apartment,
    );
    await pumpFiles(tester, f, location: '/files/folder/$apartment');
    await realTap(tester, cardMore);
    await realTap(tester, find.text('Info'));
    expect(find.text('Files › Apartment'), findsOneWidget);
    expect(find.text(formatBytes(2400000, 'en')), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('1.7'), findsOneWidget);
    expect(find.text('Make searchable'), findsOneWidget);
    expect(find.text('Versions'), findsOneWidget);
    expect(find.textContaining('· current'), findsOneWidget);
  });

  testWidgets('an older version is listed with Restore, and restores', (
    tester,
  ) async {
    final id = await seed(tester);
    await tester.runAsync(() async {
      final store = VersionStore(
        f.db,
        Directory('${f.root.path}/work/versions'),
      );
      await store.save(id); // the original
      File('${f.root.path}/Dokulo/Vertrag.pdf')
          .writeAsStringSync('%PDF-1.4 signed');
    });
    await pumpFiles(tester, f);
    await realTap(tester, cardMore);
    await realTap(tester, find.text('Info'));
    expect(find.text('Restore'), findsOneWidget);
    await realTap(tester, find.text('Restore'));
    expect(
      File('${f.root.path}/Dokulo/Vertrag.pdf').readAsStringSync(),
      startsWith('%PDF-1.7'),
    );
  });

  test('readPdfVersion reads the header, nothing else', () async {
    final dir = await Directory.systemTemp.createTemp('dk_ver_');
    addTearDown(() => dir.delete(recursive: true));
    final pdf = File('${dir.path}/a.pdf')..writeAsStringSync('%PDF-2.0\n');
    final png = File('${dir.path}/b.png')..writeAsBytesSync([0x89, 0x50]);
    expect(await readPdfVersion(pdf.path), '2.0');
    expect(await readPdfVersion(png.path), isNull);
    expect(await readPdfVersion('${dir.path}/gone.pdf'), isNull);
  });
}
