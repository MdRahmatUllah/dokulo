import 'dart:convert';
import 'dart:io';

import 'package:doc_core/doc_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late DokuloDatabase db;
  late FileStore files;
  late LockedStore vault;
  late LockedCipher cipher;
  final sep = Platform.pathSeparator;

  const pdf = '%PDF-1.7\nPersonalausweis L01X00T47 Mustermann';

  setUp(() async {
    root = await Directory.systemTemp.createTemp('dk_vault_');
    db = DokuloDatabase.memory();
    files = FileStore(
      userFolder: Directory('${root.path}${sep}Dokulo'),
      workDirectory: Directory('${root.path}${sep}work'),
    );
    vault = LockedStore(Directory('${root.path}${sep}work${sep}locked'));
    cipher = LockedCipher(await LockedCipher.newKey());
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<int> addFile(String name, {int? folder, String body = pdf}) async {
    final dir = await files.folderDirectory(db, folder);
    final f = File('${dir.path}$sep$name')
      ..createSync(recursive: true)
      ..writeAsStringSync(body);
    return db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            path: f.path,
            name: name,
            size: body.length,
            pages: const Value(2),
            created: DateTime(2026, 10, 1),
            modified: DateTime(2026, 10, 1),
            folderId: Value(folder),
          ),
        );
  }

  /// Every byte under the vault, as text: none of the file may show.
  String vaultBytes() => [
    for (final f in vault.directory.listSync(recursive: true))
      if (f is File) latin1.decode(f.readAsBytesSync()),
  ].join();

  test('move in: sealed in the vault, the plain file and row gone', () async {
    final id = await addFile('Ausweis.pdf');
    final path = '${files.userFolder.path}${sep}Ausweis.pdf';
    await db.customStatement(
      'INSERT INTO ocr_text (file_id, page, page_text) VALUES (?, 1, ?)',
      [id, 'Mustermann'],
    );
    final entry = await vault.moveIn(db, id, cipher);
    expect(File(path).existsSync(), isFalse);
    expect(await db.select(db.files).get(), isEmpty);
    expect(await db.searchText('Mustermann').get(), isEmpty);
    expect(entry.name, 'Ausweis.pdf');
    final text = vaultBytes();
    expect(text, isNot(contains('%PDF')));
    expect(text, isNot(contains('Mustermann')));
    // Not even the name is in the clear.
    expect(text, isNot(contains('Ausweis')));
    expect((await vault.list(cipher)).single.name, 'Ausweis.pdf');
  });

  test('open decrypts to the open folder; closeAll removes it', () async {
    final entry = await vault.moveIn(db, await addFile('a.pdf'), cipher);
    final clear = await vault.open(entry.id, cipher);
    expect(clear.readAsStringSync(), pdf);
    expect(clear.path, startsWith(vault.openDirectory.path));
    await vault.closeAll();
    expect(clear.existsSync(), isFalse);
    expect(vault.openDirectory.existsSync(), isFalse);
  });

  test('move out: back in its folder, indexed, gone from the vault', () async {
    final taxes = await files.createFolder(db, 'Taxes');
    final entry = await vault.moveIn(
      db,
      await addFile('b.pdf', folder: taxes),
      cipher,
    );
    expect(entry.fromFolder, taxes);
    final back = await vault.moveOut(
      db,
      files,
      entry.id,
      cipher,
      folder: entry.fromFolder,
    );
    final row = await (db.select(
      db.files,
    )..where((f) => f.id.equals(back))).getSingle();
    expect(row.folderId, taxes);
    expect(File(row.path).readAsStringSync(), pdf);
    expect(await vault.list(cipher), isEmpty);
    expect(
      vault.directory.listSync().whereType<File>().map((f) => f.path),
      everyElement(endsWith('index.dkl')),
    );
  });

  test('move out to a folder that was deleted: the root', () async {
    final gone = await files.createFolder(db, 'Gone');
    final entry = await vault.moveIn(
      db,
      await addFile('c.pdf', folder: gone),
      cipher,
    );
    await files.deleteFolder(db, gone);
    final back = await vault.moveOut(db, files, entry.id, cipher, folder: gone);
    final row = await (db.select(
      db.files,
    )..where((f) => f.id.equals(back))).getSingle();
    expect(row.folderId, isNull);
  });

  test('a failing seal leaves the original as it was', () async {
    final id = await addFile('keep.pdf');
    // The vault's place is taken by a file: creating it fails.
    File('${root.path}${sep}not-a-dir').createSync();
    final broken = LockedStore(Directory('${root.path}${sep}not-a-dir'));
    await expectLater(broken.moveIn(db, id, cipher), throwsA(anything));
    expect(
      File('${files.userFolder.path}${sep}keep.pdf').readAsStringSync(),
      pdf,
    );
    expect(await db.select(db.files).get(), hasLength(1));
  });

  test('the key itself is nowhere in the vault', () async {
    final key = await LockedCipher.newKey();
    final own = LockedCipher(key);
    await vault.moveIn(db, await addFile('k.pdf'), own);
    final bytes = [
      for (final f in vault.directory.listSync(recursive: true))
        if (f is File) ...f.readAsBytesSync(),
    ];
    // No 8-byte run of the key appears in what's on disk.
    for (var i = 0; i + 8 <= key.length; i += 8) {
      final run = key.sublist(i, i + 8);
      var found = false;
      for (var j = 0; j + 8 <= bytes.length && !found; j++) {
        found = Iterable<int>.generate(8).every((k) => bytes[j + k] == run[k]);
      }
      expect(found, isFalse, reason: 'key bytes $i..${i + 8}');
    }
  });

  test('the wrong key reads no list', () async {
    await vault.moveIn(db, await addFile('d.pdf'), cipher);
    final other = LockedCipher(await LockedCipher.newKey());
    await expectLater(vault.list(other), throwsA(isA<LockedDataException>()));
  });
}
