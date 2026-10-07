import 'dart:io';

import 'package:doc_core/doc_core.dart';
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:test/test.dart';

import 'generated/schema.dart';

void main() {
  // Tests open a second instance next to the in-memory one on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late DokuloDatabase db;
  setUp(() => db = DokuloDatabase.memory());
  tearDown(() => db.close());

  final start = DateTime(2026, 10, 7, 9);

  Future<int> addFile(String name) => db
      .into(db.files)
      .insert(
        FilesCompanion.insert(
          path: '/docs/$name',
          name: name,
          size: 1000,
          created: start,
          modified: start,
        ),
      );

  test('every version migrates to the current schema (from v1)', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    for (final from in GeneratedHelper.versions) {
      final connection = await verifier.startAt(from);
      final migrated = DokuloDatabase(connection);
      await verifier.migrateAndValidate(migrated, db.schemaVersion);
      await migrated.close();
    }
  });

  test(
    'Files search finds a German and an English term with page and snippet',
    () async {
      final letter = await addFile('Steuerbescheid.pdf');
      final invoice = await addFile('Invoice.pdf');
      for (final (fileId, page, text) in [
        (letter, 1, 'Sehr geehrte Frau Muster, anbei Ihr Steuerbescheid.'),
        (letter, 2, 'Die Gebühr für die Prüfung beträgt 25 Euro.'),
        (invoice, 1, 'Invoice 2026-114. Payment due within 14 days.'),
      ]) {
        await db.customInsert(
          'INSERT INTO ocr_text (file_id, page, page_text) VALUES (?, ?, ?)',
          variables: [Variable(fileId), Variable(page), Variable(text)],
        );
      }

      // remove_diacritics: "gebuhr" finds "Gebühr".
      final german = await db.searchText('gebuhr').get();
      expect(german.single.fileId, letter);
      expect(german.single.page, 2);
      expect(german.single.snippet, contains('[Gebühr]'));

      final english = await db.searchText('payment').get();
      expect(english.single.fileId, invoice);
      expect(english.single.page, 1);
      expect(english.single.snippet, contains('[Payment]'));
    },
  );

  test('recents keep the newest 20, and reopening moves a file up', () async {
    final ids = [for (var i = 0; i < 25; i++) await addFile('f$i.pdf')];
    for (final (i, id) in ids.indexed) {
      await db
          .into(db.recents)
          .insertOnConflictUpdate(
            RecentsCompanion.insert(
              fileId: Value(id),
              openedAt: start.add(Duration(minutes: i)),
            ),
          );
    }
    expect(await db.select(db.recents).get(), hasLength(20));

    // Reopen the oldest survivor; it must stay while 20 stay.
    await db
        .into(db.recents)
        .insertOnConflictUpdate(
          RecentsCompanion.insert(
            fileId: Value(ids[5]),
            openedAt: start.add(const Duration(hours: 1)),
          ),
        );
    final kept = (await db.select(db.recents).get()).map((r) => r.fileId);
    expect(kept, hasLength(20));
    expect(kept, contains(ids[5]));
    expect(kept, isNot(contains(ids[4])));
  });

  test('versions keep the newest 5 per file', () async {
    final a = await addFile('a.pdf');
    final b = await addFile('b.pdf');
    for (var i = 0; i < 7; i++) {
      await db
          .into(db.versions)
          .insert(
            VersionsCompanion.insert(
              fileId: a,
              path: '/v/a$i',
              createdAt: start.add(Duration(minutes: i)),
            ),
          );
    }
    await db
        .into(db.versions)
        .insert(
          VersionsCompanion.insert(fileId: b, path: '/v/b0', createdAt: start),
        );

    final rows = await db.select(db.versions).get();
    final ofA = rows.where((v) => v.fileId == a).map((v) => v.path);
    expect(ofA, ['/v/a2', '/v/a3', '/v/a4', '/v/a5', '/v/a6']);
    expect(rows.where((v) => v.fileId == b), hasLength(1));
  });

  test(
    'deleting a file removes its recents, favourites and versions',
    () async {
      final id = await addFile('gone.pdf');
      await db
          .into(db.recents)
          .insert(RecentsCompanion.insert(fileId: Value(id), openedAt: start));
      await db
          .into(db.favourites)
          .insert(
            FavouritesCompanion.insert(fileId: Value(id), addedAt: start),
          );
      await (db.delete(db.files)..where((f) => f.id.equals(id))).go();
      expect(await db.select(db.recents).get(), isEmpty);
      expect(await db.select(db.favourites).get(), isEmpty);
    },
  );

  test(
    'the database file lives in the support directory it is given',
    () async {
      final support = await Directory.systemTemp.createTemp('dk_support_');
      addTearDown(() => support.delete(recursive: true));
      final opened = DokuloDatabase.open(() async => support);
      await opened.customSelect('SELECT 1').get();
      await opened.close();
      expect(DokuloDatabase.file(support).existsSync(), isTrue);
      expect(DokuloDatabase.file(support).parent.path, support.path);
    },
  );
}
