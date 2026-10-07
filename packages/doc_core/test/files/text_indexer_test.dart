import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:qpdf_ffi/qpdf_ffi.dart';
import 'package:test/test.dart';

/// The shared sample corpus (DK-0023), from the repo root.
String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

void _extract((String, String, String) job, JobContext context) =>
    QpdfService.run(() => Qpdf.extract(job.$1, job.$2, job.$3));

void main() {
  setUpAll(pdfrxInitialize);
  late Directory dir, folder;
  late DokuloDatabase db;
  late FileStore store;
  late TextIndexer indexer;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('dk_index_test_');
    folder = Directory('${dir.path}/Dokulo')..createSync();
    db = DokuloDatabase.memory();
    store = FileStore(
      userFolder: folder,
      workDirectory: Directory('${dir.path}/work'),
    );
    indexer = TextIndexer(db);
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<FileEntry> row(String name) =>
      (db.select(db.files)..where((f) => f.name.equals(name))).getSingle();

  test(
    'a saved 10-page PDF is searchable within 5 s, with page numbers',
    () async {
      final pool = IsolatePool(
        tempRoot: Directory('${dir.path}/jobs')..createSync(),
      );
      await pool.run(Lane.qpdf, _extract, (
        fixture('long-300-pages.pdf'),
        '1-10',
        '${folder.path}/Ten pages.pdf',
      )).result;
      final clock = Stopwatch()..start();
      await store.reconcile(db);
      expect(await indexer.catchUp(), 1);
      expect(clock.elapsed, lessThan(const Duration(seconds: 5)));

      final hits = await db.searchText('Abschnitt007').get();
      expect(
        (hits.single.fileId, hits.single.page),
        ((await row('Ten pages.pdf')).id, 7),
      );
      expect((await row('Ten pages.pdf')).hasText, isTrue);
      expect(await indexer.stale(), isEmpty);
    },
  );

  test(
    'a scan without text and a locked file: indexed, no searchable text',
    () async {
      for (final name in [
        'scanned-letters-bundle.pdf',
        'encrypted-aes256.pdf',
      ]) {
        File(fixture(name)).copySync('${folder.path}/$name');
      }
      File('${folder.path}/notes.txt').writeAsStringSync('not a PDF');
      await store.reconcile(db);
      expect(await indexer.catchUp(), 3);
      for (final name in [
        'scanned-letters-bundle.pdf',
        'encrypted-aes256.pdf',
        'notes.txt',
      ]) {
        expect((await row(name)).hasText, isFalse, reason: name);
      }
      expect(
        await indexer.stale(),
        isEmpty,
        reason: "they aren't retried until they change",
      );
    },
  );

  test(
    'a changed file is indexed again, its old text replaced, not added',
    () async {
      final path = '${folder.path}/Vertrag.pdf';
      File(fixture('Mietvertrag Musterstraße 12.pdf')).copySync(path);
      await store.reconcile(db);
      await indexer.catchUp();
      expect(await db.searchText('Grundmiete').get(), isNotEmpty);

      // The user replaces it (Replace original): another document, a new mtime.
      File(fixture('Invoice INV-2026-014.pdf')).copySync(path);
      File(path)
          .setLastModifiedSync(DateTime.now().add(const Duration(minutes: 1)));
      await store.reconcile(db);
      expect((await indexer.stale()).map((f) => f.name), ['Vertrag.pdf']);
      // Until it's indexed again, search still answers from the old text.
      expect(await db.searchText('Grundmiete').get(), isNotEmpty);

      await indexer.catchUp();
      expect(await db.searchText('Grundmiete').get(), isEmpty);
      expect(await db.searchText('Beispielweg').get(), hasLength(1));
    },
  );

  test(
    'a file gone mid-update leaves no half index and is not stale',
    () async {
      final path = '${folder.path}/Gone.pdf';
      File(fixture('Mietvertrag Musterstraße 12.pdf')).copySync(path);
      await store.reconcile(db);
      final file = (await indexer.stale()).single;
      File(path).deleteSync(); // gone between listing and indexing
      await indexer.index(file);
      final rows = await db
          .customSelect('SELECT COUNT(*) AS n FROM ocr_text', readsFrom: {})
          .getSingle();
      expect(rows.read<int>('n'), 0);
      expect(await indexer.stale(), isEmpty);
    },
  );

  test(
    'the migration from v2 adds indexed_at, NULL for existing files',
    () async {
      final columns = await db
          .customSelect("SELECT name FROM pragma_table_info('files')")
          .get();
      expect(
        columns.map((c) => c.read<String>('name')),
        contains('indexed_at'),
      );
      await db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              path: '/x.pdf',
              name: 'x.pdf',
              size: 1,
              created: DateTime(2026),
              modified: DateTime(2026),
            ),
          );
      expect((await indexer.stale()).single.indexedAt, isNull);
    },
  );
}
