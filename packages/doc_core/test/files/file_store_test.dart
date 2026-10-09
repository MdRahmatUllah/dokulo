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
