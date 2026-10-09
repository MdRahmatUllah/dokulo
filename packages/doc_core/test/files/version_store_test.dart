import 'dart:io';

import 'package:doc_core/doc_core.dart';
import 'package:drift/drift.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late DokuloDatabase db;
  late VersionStore versions;
  late File pdf;
  late int fileId;
  var now = DateTime(2026, 10, 9, 12);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('dk_versions_');
    db = DokuloDatabase.memory();
    now = DateTime(2026, 10, 9, 12);
    versions = VersionStore(
      db,
      Directory('${root.path}${Platform.pathSeparator}versions'),
      clock: () => now,
    );
    pdf = File('${root.path}${Platform.pathSeparator}Vertrag.pdf')
      ..writeAsStringSync('v0');
    fileId = await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            path: pdf.path,
            name: 'Vertrag.pdf',
            size: 2,
            created: now,
            modified: now,
          ),
        );
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  /// An edit: keep a version, then overwrite the file.
  Future<void> edit(String content) async {
    await versions.save(fileId);
    pdf.writeAsStringSync(content);
    now = now.add(const Duration(minutes: 1));
  }

  List<File> copiesOnDisk() =>
      versions.directory.listSync().whereType<File>().toList();

  test('save keeps what the file was, newest first', () async {
    await edit('v1');
    await edit('v2');
    final list = await versions.list(fileId);
    expect(list.map((v) => File(v.path).readAsStringSync()), ['v1', 'v0']);
    expect(pdf.readAsStringSync(), 'v2');
  });

  test('at most 5 per file; the dropped copies leave the disk too', () async {
    for (var i = 1; i <= 8; i++) {
      await edit('v$i');
    }
    final list = await versions.list(fileId);
    expect(list, hasLength(VersionStore.keep));
    expect(list.map((v) => File(v.path).readAsStringSync()), [
      'v7',
      'v6',
      'v5',
      'v4',
      'v3',
    ]);
    expect(copiesOnDisk(), hasLength(VersionStore.keep));
  });

  test('restore puts a version back and keeps the current one', () async {
    await edit('v1');
    await edit('v2'); // versions: v1, v0; file: v2
    final v0 = (await versions.list(fileId)).last;
    await versions.restore(v0);
    expect(pdf.readAsStringSync(), 'v0');
    final list = await versions.list(fileId);
    expect(list.map((v) => File(v.path).readAsStringSync()), ['v2', 'v1']);
    final row = await (db.select(
      db.files,
    )..where((f) => f.id.equals(fileId))).getSingle();
    expect(row.size, 2);
    expect(copiesOnDisk(), hasLength(2));
  });

  test('purge drops versions older than 30 days, files and rows', () async {
    await edit('v1'); // the copy of v0, at day 0
    now = now.add(const Duration(days: 20));
    await edit('v2'); // the copy of v1, at day 20
    now = now.add(const Duration(days: 11)); // day 31
    expect(await versions.purge(), 1);
    final list = await versions.list(fileId);
    expect(list.map((v) => File(v.path).readAsStringSync()), ['v1']);
    expect(copiesOnDisk(), hasLength(1));
  });

  test('purge deletes copies no row points to', () async {
    await edit('v1');
    // The file is deleted: its versions' rows cascade, the copies stay.
    await (db.delete(db.files)..where((f) => f.id.equals(fileId))).go();
    expect(await db.select(db.versions).get(), isEmpty);
    expect(copiesOnDisk(), hasLength(1));
    expect(await versions.purge(), 1);
    expect(copiesOnDisk(), isEmpty);
  });

  test('purge with no versions yet does nothing', () async {
    expect(await versions.purge(), 0);
  });
}
