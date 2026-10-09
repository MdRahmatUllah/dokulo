import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:doc_core/doc_core.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

/// The shared sample corpus (DK-0023), from the repo root.
String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

void main() {
  setUpAll(pdfrxInitialize);
  late Directory root;
  late FileStore store;
  late DokuloDatabase db;
  final sep = Platform.pathSeparator;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('dk_store_');
    store = FileStore(
      userFolder: Directory('${root.path}${sep}Dokulo'),
      workDirectory: Directory('${root.path}${sep}sandbox'),
    );
    db = DokuloDatabase.memory();
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<String> hash(File f) async =>
      sha256.convert(await f.readAsBytes()).toString();

  File userFile(String relative) =>
      File('${store.userFolder.path}$sep$relative');

  test('a tool run never modifies the original (by hash)', () async {
    final original = File('${root.path}${sep}Rechnung.pdf')
      ..writeAsStringSync('%PDF-1.7 original');
    final before = await hash(original);

    final copy = await store.importIncoming(original);
    expect(copy.path, startsWith(store.inbox.path));
    // A "tool" reads the copy and writes a new file in temp.
    final output = await store.newTempFile('Rechnung – compressed.pdf');
    await output.writeAsString('${await copy.readAsString()} compressed');
    await store.save(output, name: 'Rechnung – compressed.pdf');

    expect(await hash(original), before);
  });

  test(
    'save moves the output into the user folder under a free name',
    () async {
      Future<File> saveOne(String folder) async {
        final out = await store.newTempFile('Scan.pdf');
        await out.writeAsString('pdf');
        return store.save(out, name: 'Scan.pdf', subfolder: folder);
      }

      final first = await saveOne('Rechnungen');
      final second = await saveOne('Rechnungen');
      expect(first.path, userFile('Rechnungen${sep}Scan.pdf').path);
      expect(second.path, userFile('Rechnungen${sep}Scan (2).pdf').path);
      expect(store.temp.listSync(), isEmpty);
    },
  );

  test('the temp directory is empty after save or share completes', () async {
    final incoming = File('${root.path}${sep}in.pdf')..writeAsStringSync('x');
    await store.importIncoming(incoming);
    final shared = await store.newTempFile('out.pdf');
    await shared.writeAsString('y');

    await store.clearTemp();
    expect(store.temp.existsSync(), isFalse);
    expect(store.inbox.existsSync(), isFalse);
    expect(incoming.existsSync(), isTrue);
  });

  test('reconcile adds new files with their folders, updates changed ones, '
      'and drops files deleted outside the app', () async {
    userFile('Brief.pdf')
      ..createSync(recursive: true)
      ..writeAsStringSync('a');
    userFile('Steuer${sep}2026${sep}Bescheid.pdf')
      ..createSync(recursive: true)
      ..writeAsStringSync('bb');
    userFile('.hidden')
      ..createSync()
      ..writeAsStringSync('ignored');

    await store.reconcile(db);
    var files = await db.select(db.files).get();
    expect(
      files.map((f) => f.name),
      unorderedEquals(['Brief.pdf', 'Bescheid.pdf']),
    );
    final bescheid = files.singleWhere((f) => f.name == 'Bescheid.pdf');
    final year = await (db.select(
      db.folders,
    )..where((f) => f.id.equals(bescheid.folderId!))).getSingle();
    final steuer = await (db.select(
      db.folders,
    )..where((f) => f.id.equals(year.parentId!))).getSingle();
    expect((year.name, steuer.name, steuer.parentId), ('2026', 'Steuer', null));
    expect(files.singleWhere((f) => f.name == 'Brief.pdf').folderId, isNull);

    // Changed and deleted outside the app, then pull-to-refresh.
    userFile('Brief.pdf').writeAsStringSync('a longer letter');
    userFile('Steuer${sep}2026${sep}Bescheid.pdf').deleteSync();
    await store.reconcile(db);
    await store.reconcile(db); // idempotent

    files = await db.select(db.files).get();
    expect(files.single.name, 'Brief.pdf');
    expect(files.single.size, 'a longer letter'.length);
    expect(await db.select(db.folders).get(), hasLength(2));
  });

  test(
    'importToUserFolder: a copy in Dokulo, indexed; the original stays',
    () async {
      final picked = File('${root.path}${sep}Downloads${sep}Rechnung.pdf')
        ..createSync(recursive: true)
        ..writeAsStringSync('%PDF-1.7 picked');
      final id = await store.importToUserFolder(db, picked);
      final row = await (db.select(
        db.files,
      )..where((f) => f.id.equals(id))).getSingle();
      expect(row.name, 'Rechnung.pdf');
      expect(row.path, startsWith(store.userFolder.path));
      expect(File(row.path).readAsStringSync(), '%PDF-1.7 picked');
      expect(picked.existsSync(), isTrue);
      // The same file again: a second copy under a free name.
      final again = await store.importToUserFolder(db, picked);
      final second = await (db.select(
        db.files,
      )..where((f) => f.id.equals(again))).getSingle();
      expect(second.name, 'Rechnung (2).pdf');
      // A reconcile keeps both rows as they are.
      await store.reconcile(db);
      expect(await db.select(db.files).get(), hasLength(2));
    },
  );

  group('renameFolder and deleteFolder (DK-0262)', () {
    Future<int> fileIn(int folder, String relative) async {
      final f = File('${store.userFolder.path}$sep$relative')
        ..createSync(recursive: true)
        ..writeAsStringSync('%PDF');
      return db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              path: f.path,
              name: relative.split('/').last,
              size: 4,
              created: DateTime(2026),
              modified: DateTime(2026),
              folderId: Value(folder),
            ),
          );
    }

    test('rename moves the directory and every path under it', () async {
      final taxes = await store.createFolder(db, 'Taxes');
      final year = await store.createFolder(db, '2026', parent: taxes);
      final a = await fileIn(year, 'Taxes${sep}2026${sep}Bescheid.pdf');
      await store.renameFolder(db, taxes, 'Steuern');
      expect(
        Directory('${store.userFolder.path}${sep}Steuern${sep}2026')
            .existsSync(),
        isTrue,
      );
      expect(
        Directory('${store.userFolder.path}${sep}Taxes').existsSync(),
        isFalse,
      );
      final row = await (db.select(
        db.files,
      )..where((f) => f.id.equals(a))).getSingle();
      expect(
        row.path,
        '${store.userFolder.path}${sep}Steuern${sep}2026${sep}Bescheid.pdf',
      );
      expect(File(row.path).existsSync(), isTrue);
      // Index and disk agree: reconcile changes nothing.
      await store.reconcile(db);
      expect(await db.select(db.files).get(), hasLength(1));
      expect(await db.select(db.folders).get(), hasLength(2));
    });

    test(
      'rename: a taken name is refused; only a case change is fine',
      () async {
        final taxes = await store.createFolder(db, 'Taxes');
        await store.createFolder(db, 'Work');
        expect(
          () => store.renameFolder(db, taxes, 'work'),
          throwsA(isA<FolderNameException>()),
        );
        await store.renameFolder(db, taxes, 'TAXES');
        final row = await (db.select(
          db.folders,
        )..where((f) => f.id.equals(taxes))).getSingle();
        expect(row.name, 'TAXES');
      },
    );

    test('delete sends the files to the trash, subfolders too', () async {
      final taxes = await store.createFolder(db, 'Taxes');
      final year = await store.createFolder(db, '2026', parent: taxes);
      final a = await fileIn(taxes, 'Taxes${sep}a.pdf');
      final b = await fileIn(year, 'Taxes${sep}2026${sep}b.pdf');
      expect(await store.deleteFolder(db, taxes), 2);
      expect(await db.select(db.folders).get(), isEmpty);
      final trashed = {
        for (final t in await db.select(db.trash).get()) t.fileId,
      };
      expect(trashed, {a, b});
      // Still on disk until the trash lets them go.
      expect(
        File('${store.userFolder.path}${sep}Taxes${sep}a.pdf').existsSync(),
        isTrue,
      );
    });

    test('an empty folder goes at once, its directory too', () async {
      final empty = await store.createFolder(db, 'Empty');
      expect(await store.deleteFolder(db, empty), 0);
      expect(
        Directory('${store.userFolder.path}${sep}Empty').existsSync(),
        isFalse,
      );
    });
  });

  group('file actions (DK-0271, DK-0272, DK-0274, DK-0276)', () {
    Future<int> addFile(String relative, {int? folder}) async {
      final f = File('${store.userFolder.path}$sep$relative')
        ..createSync(recursive: true)
        ..writeAsStringSync('%PDF $relative');
      return db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              path: f.path,
              name: relative.split(sep).last,
              size: 9,
              created: DateTime(2026),
              modified: DateTime(2026),
              folderId: Value(folder),
            ),
          );
    }

    Future<FileEntry> row(int id) =>
        (db.select(db.files)..where((f) => f.id.equals(id))).getSingle();

    test('rename keeps the extension and drops bad characters', () async {
      final id = await addFile('Vertrag.pdf');
      await store.renameFile(db, id, ' Miet:vertrag 2026? ');
      final r = await row(id);
      expect(r.name, 'Mietvertrag 2026.pdf');
      expect(File(r.path).existsSync(), isTrue);
      expect(
        File('${store.userFolder.path}${sep}Vertrag.pdf').existsSync(),
        isFalse,
      );
    });

    test('rename to a taken name is refused; a case change is fine', () async {
      final a = await addFile('a.pdf');
      await addFile('b.pdf');
      expect(
        () => store.renameFile(db, a, 'b'),
        throwsA(isA<FileNameException>()),
      );
      await store.renameFile(db, a, 'A');
      expect((await row(a)).name, 'A.pdf');
      expect(
        () => store.renameFile(db, a, '  '),
        throwsA(isA<FileNameException>()),
      );
    });

    test(
      'duplicate numbers without collisions; Undo removes the copy',
      () async {
        final id = await addFile('Vertrag.pdf');
        final copy1 = await store.duplicateFile(db, id);
        final copy2 = await store.duplicateFile(db, id);
        expect((await row(copy1)).name, 'Vertrag (2).pdf');
        expect((await row(copy2)).name, 'Vertrag (3).pdf');
        await store.deleteCopy(db, copy2);
        expect(
          File('${store.userFolder.path}${sep}Vertrag (3).pdf').existsSync(),
          isFalse,
        );
        expect(await db.select(db.files).get(), hasLength(2));
      },
    );

    test('move into a folder and back (Undo)', () async {
      final taxes = await store.createFolder(db, 'Taxes');
      final id = await addFile('Bescheid.pdf');
      final was = await store.moveFile(db, id, taxes);
      expect(was, isNull);
      final moved = await row(id);
      expect(moved.folderId, taxes);
      expect(
        moved.path,
        '${store.userFolder.path}${sep}Taxes${sep}Bescheid.pdf',
      );
      expect(File(moved.path).existsSync(), isTrue);
      await store.moveFile(db, id, was);
      expect(
        (await row(id)).path,
        '${store.userFolder.path}${sep}Bescheid.pdf',
      );
      await store.reconcile(db);
      expect(await db.select(db.files).get(), hasLength(1));
    });

    test('move onto a taken name takes the next free one', () async {
      final taxes = await store.createFolder(db, 'Taxes');
      await addFile('Taxes${sep}x.pdf', folder: taxes);
      final id = await addFile('x.pdf');
      await store.moveFile(db, id, taxes);
      expect((await row(id)).name, 'x (2).pdf');
    });

    test('trash and restore', () async {
      final id = await addFile('t.pdf');
      await store.trashFile(db, id);
      expect(await db.select(db.trash).get(), hasLength(1));
      await store.restoreFromTrash(db, id);
      expect(await db.select(db.trash).get(), isEmpty);
    });
  });

  group('createFolder (DK-0273)', () {
    test('makes the directory and its row, nested too', () async {
      final taxes = await store.createFolder(db, 'Taxes');
      final year = await store.createFolder(db, ' 2026 ', parent: taxes);
      expect(
        Directory('${store.userFolder.path}${sep}Taxes').existsSync(),
        isTrue,
      );
      expect(
        (await store.folderDirectory(db, year)).path,
        '${store.userFolder.path}${sep}Taxes${sep}2026',
      );
      expect(
        Directory('${store.userFolder.path}${sep}Taxes${sep}2026').existsSync(),
        isTrue,
      );
      // A reconcile finds the same rows, not new ones.
      await store.reconcile(db);
      expect(await db.select(db.folders).get(), hasLength(2));
    });

    test('a taken name is refused, whatever its case', () async {
      await store.createFolder(db, 'Taxes');
      expect(
        () => store.createFolder(db, 'taxes'),
        throwsA(
          isA<FolderNameException>().having(
            (e) => e.problem,
            'problem',
            FolderNameProblem.taken,
          ),
        ),
      );
      // The same name elsewhere is fine.
      final work = await store.createFolder(db, 'Work');
      expect(await store.createFolder(db, 'Taxes', parent: work), isPositive);
    });

    test('empty, dot and path names are refused', () async {
      for (final name in ['', '  ', '.', '..', 'a/b', r'a\b']) {
        expect(
          () => store.createFolder(db, name),
          throwsA(isA<FolderNameException>()),
          reason: '"$name"',
        );
      }
      expect(await store.createFolder(db, 'Rechnungen (alt)'), isPositive);
    });
  });

  test("a tool's result is saved next to its input and indexed, with its "
      'pages (DK-0379)', () async {
    final input = userFile('Taxes${sep}2026${sep}Bescheid.pdf');
    await input.parent.create(recursive: true);
    await File(fixture('Invoice INV-2026-014.pdf')).copy(input.path);
    expect(store.subfolderOf(input.path), 'Taxes${sep}2026');
    expect(store.subfolderOf(userFile('Root.pdf').path), isNull);
    expect(store.subfolderOf('${store.inbox.path}${sep}Shared.pdf'), isNull);

    final out = await store.newTempFile('Bescheid – compressed.pdf');
    await File(fixture('Invoice INV-2026-014.pdf')).copy(out.path);
    final row = await store.saveIndexed(
      db,
      out,
      name: 'Bescheid – compressed.pdf',
      subfolder: store.subfolderOf(input.path),
    );
    expect(
      row.path,
      userFile('Taxes${sep}2026${sep}Bescheid – compressed.pdf').path,
    );
    expect(row.pages, greaterThan(0));
    expect(row.folderId, isNotNull);
    expect(await out.exists(), isFalse, reason: 'moved out of temp');
  });
}
