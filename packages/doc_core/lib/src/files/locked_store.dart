import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';

import '../db/database.dart';
import 'file_store.dart';
import 'locked_crypto.dart';

/// A file in the locked folder: what F2 lists. Everything here lives in the
/// sealed manifest, never in the plain index.
class LockedEntry {
  const LockedEntry({
    required this.id,
    required this.name,
    required this.size,
    required this.pages,
    required this.added,
    this.fromFolder,
  });

  /// The sealed file's name in the vault (random, says nothing).
  final String id;
  final String name;
  final int size;
  final int pages;
  final DateTime added;

  /// The folder it came from: Undo and "move out" put it back there.
  final int? fromFolder;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'size': size,
    'pages': pages,
    'added': added.toIso8601String(),
    'from': fromFolder,
  };

  factory LockedEntry.fromJson(Map<String, Object?> j) => LockedEntry(
    id: j['id']! as String,
    name: j['name']! as String,
    size: j['size']! as int,
    pages: j['pages']! as int,
    added: DateTime.parse(j['added']! as String),
    fromFolder: j['from'] as int?,
  );
}

/// The locked folder's vault (DK-0289): each file sealed with the folder's
/// key ([LockedCipher], AES-256-GCM) under a random name in [directory], in
/// the app sandbox (never the visible user folder), and one sealed manifest
/// with the names. A file is decrypted only to [openDirectory] while the
/// user looks at it; [closeAll] (on lock) deletes those copies.
class LockedStore {
  LockedStore(this.directory);

  final Directory directory;

  File get _manifest =>
      File('${directory.path}${Platform.pathSeparator}index.dkl');
  File _sealed(String id) =>
      File('${directory.path}${Platform.pathSeparator}$id.dkl');

  /// Decrypted copies, while open; next to the vault, cleared on lock.
  Directory get openDirectory =>
      Directory('${directory.path}${Platform.pathSeparator}open');

  Future<List<LockedEntry>> list(LockedCipher cipher) async {
    if (!await _manifest.exists()) return const [];
    final clear = await cipher.open(await _manifest.readAsBytes());
    return [
      for (final j in jsonDecode(utf8.decode(clear)) as List)
        LockedEntry.fromJson((j as Map).cast()),
    ];
  }

  Future<void> _save(List<LockedEntry> entries, LockedCipher cipher) async {
    await directory.create(recursive: true);
    final sealed = await cipher.seal(
      utf8.encode(jsonEncode([for (final e in entries) e.toJson()])),
    );
    // Write then rename: a crash mid-write never leaves a torn manifest.
    final tmp = File('${_manifest.path}.tmp');
    await tmp.writeAsBytes(sealed, flush: true);
    await tmp.rename(_manifest.path);
  }

  /// Moves file [fileId] in: sealed into the vault, checked by opening it
  /// again, then the plain file overwritten and deleted and its row (with
  /// its text index) removed. Anything failing before that leaves the
  /// original as it was.
  Future<LockedEntry> moveIn(
    DokuloDatabase db,
    int fileId,
    LockedCipher cipher,
  ) async {
    final row = await (db.select(
      db.files,
    )..where((f) => f.id.equals(fileId))).getSingle();
    final clear = File(row.path);
    final bytes = await clear.readAsBytes();
    final entry = LockedEntry(
      id: _randomId(),
      name: row.name,
      size: bytes.length,
      pages: row.pages,
      added: DateTime.now(),
      fromFolder: row.folderId,
    );
    final sealed = _sealed(entry.id);
    try {
      await directory.create(recursive: true);
      await sealed.writeAsBytes(await cipher.seal(bytes), flush: true);
      final back = await cipher.open(await sealed.readAsBytes());
      if (!_same(back, bytes)) {
        throw const LockedDataException('the sealed copy reads back wrong');
      }
      await _save([...await list(cipher), entry], cipher);
    } catch (_) {
      if (await sealed.exists()) await sealed.delete();
      rethrow;
    }
    await _shred(clear);
    await db.customStatement('DELETE FROM ocr_text WHERE file_id = ?', [
      fileId,
    ]);
    await (db.delete(db.files)..where((f) => f.id.equals(fileId))).go();
    return entry;
  }

  /// Moves [id] out: decrypted into [folder] (null: the root; a folder
  /// that's gone: the root) under a free name, indexed again. Returns the
  /// new row's id.
  Future<int> moveOut(
    DokuloDatabase db,
    FileStore files,
    String id,
    LockedCipher cipher, {
    int? folder,
  }) async {
    final entries = await list(cipher);
    final entry = entries.firstWhere((e) => e.id == id);
    await files.temp.create(recursive: true);
    final tmp = File(
      '${files.temp.path}${Platform.pathSeparator}${entry.name}',
    );
    await cipher.openFile(_sealed(id), tmp);
    final int fileId;
    try {
      fileId = await files.importToUserFolder(db, tmp);
    } finally {
      await _shred(tmp);
    }
    final exists =
        folder != null &&
        await (db.select(
              db.folders,
            )..where((f) => f.id.equals(folder))).getSingleOrNull() !=
            null;
    if (exists) await files.moveFile(db, fileId, folder);
    await _save([
      for (final e in entries)
        if (e.id != id) e,
    ], cipher);
    await _sealed(id).delete();
    return fileId;
  }

  /// [id] decrypted for viewing, in [openDirectory] under its name.
  Future<File> open(String id, LockedCipher cipher) async {
    final entry = (await list(cipher)).firstWhere((e) => e.id == id);
    final dir = Directory('${openDirectory.path}${Platform.pathSeparator}$id');
    await dir.create(recursive: true);
    final clear = File('${dir.path}${Platform.pathSeparator}${entry.name}');
    if (!await clear.exists()) await cipher.openFile(_sealed(id), clear);
    return clear;
  }

  /// Deletes every decrypted copy (the folder locks).
  Future<void> closeAll() async {
    if (!await openDirectory.exists()) return;
    await for (final f in openDirectory.list(recursive: true)) {
      if (f is File) await _shred(f);
    }
    await openDirectory.delete(recursive: true);
  }

  /// Overwrites [file] with zeros before deleting it, so the plain bytes
  /// don't sit in the freed blocks. ponytail: one pass; flash storage remaps
  /// blocks, so this is best effort, as the spec's "securely" can be on a
  /// phone (the OS's file encryption covers the rest).
  static Future<void> _shred(File file) async {
    if (!await file.exists()) return;
    final length = await file.length();
    final raf = await file.open(mode: FileMode.writeOnlyAppend);
    try {
      await raf.setPosition(0);
      const chunk = 1 << 16;
      final zeros = Uint8List(chunk);
      for (var done = 0; done < length; done += chunk) {
        await raf.writeFrom(zeros, 0, min(chunk, length - done));
      }
      await raf.flush();
    } finally {
      await raf.close();
    }
    await file.delete();
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String _randomId() {
    final r = Random.secure();
    return [
      for (var i = 0; i < 16; i++)
        r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }
}
