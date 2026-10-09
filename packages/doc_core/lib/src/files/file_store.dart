import 'dart:io';

import 'package:drift/drift.dart';

import '../db/database.dart';

/// Where the user's files live and how files move (DK-0006).
///
/// - [userFolder] is the visible "Dokulo" folder: iOS Documents (shown in the
///   Files app), Android `Documents/Dokulo`.
/// - [workDirectory] is in the app sandbox. `inbox/` holds the copies of
///   incoming files (share sheet, picker), so a tool never touches the
///   original. `temp/` holds job output until it is saved or shared.
///
/// A tool reads an inbox copy or a user file and writes a new file in
/// `temp/`. [save] then moves it into the user folder under a free name.
/// Nothing is ever written in place.
class FileStore {
  FileStore({required this.userFolder, required this.workDirectory});

  final Directory userFolder;
  final Directory workDirectory;

  Directory get inbox => _dir(workDirectory, 'inbox');
  Directory get temp => _dir(workDirectory, 'temp');

  /// Version history copies ([VersionStore], DK-0277).
  Directory get versions => _dir(workDirectory, 'versions');

  /// Copies an incoming file into the sandbox; the original stays untouched.
  Future<File> importIncoming(File source) async {
    await inbox.create(recursive: true);
    return source.copy(_freePath(inbox, _name(source)));
  }

  /// A fresh path in `temp/` for a job's output.
  Future<File> newTempFile(String name) async {
    await temp.create(recursive: true);
    return File(_freePath(temp, name));
  }

  /// Moves [output] (in `temp/`) into the user folder, or [subfolder] of it,
  /// as [name], or "name (2).pdf" if that is taken. Returns the saved file.
  Future<File> save(
    File output, {
    required String name,
    String? subfolder,
  }) async {
    final target = subfolder == null ? userFolder : _dir(userFolder, subfolder);
    await target.create(recursive: true);
    // Copy, then delete: the user folder may be on another volume.
    final saved = await output.copy(_freePath(target, name));
    await output.delete();
    return saved;
  }

  /// Empties `temp/` and `inbox/` (after a save or share completes).
  Future<void> clearTemp() async {
    for (final dir in [temp, inbox]) {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  }

  /// Brings the index in line with the user folder: new files are added
  /// (with their folders), changed ones updated, and rows of files deleted
  /// outside the app removed. Pull-to-refresh on Home and Files calls it.
  Future<void> reconcile(DokuloDatabase db) async {
    final onDisk = <String, FileStat>{};
    if (await userFolder.exists()) {
      await for (final entity in userFolder.list(recursive: true)) {
        if (entity is File && !_hidden(entity)) {
          onDisk[entity.path] = await entity.stat();
        }
      }
    }
    await db.transaction(() async {
      final rows = await db.select(db.files).get();
      final indexed = {for (final r in rows) r.path: r};
      for (final row in rows) {
        if (!onDisk.containsKey(row.path) && _inUserFolder(row.path)) {
          await (db.delete(db.files)..where((f) => f.id.equals(row.id))).go();
        }
      }
      for (final MapEntry(key: path, value: stat) in onDisk.entries) {
        final row = indexed[path];
        if (row == null) {
          await db
              .into(db.files)
              .insert(
                FilesCompanion.insert(
                  path: path,
                  name: _name(File(path)),
                  size: stat.size,
                  created: stat.changed,
                  modified: stat.modified,
                  folderId: Value(await _folderId(db, File(path).parent)),
                ),
              );
        } else if (row.size != stat.size ||
            row.modified != _seconds(stat.modified)) {
          await (db.update(db.files)..where((f) => f.id.equals(row.id))).write(
            FilesCompanion(
              size: Value(stat.size),
              modified: Value(stat.modified),
            ),
          );
        }
      }
    });
  }

  /// The folder row for [dir] (null for the user folder itself), creating
  /// the chain of rows on the way.
  Future<int?> _folderId(DokuloDatabase db, Directory dir) async {
    final relative = dir.path.substring(userFolder.path.length);
    int? parent;
    for (final name
        in relative.split(Platform.pathSeparator).where((s) => s.isNotEmpty)) {
      final query = db.select(db.folders)
        ..where((f) => f.name.equals(name))
        ..where(
          (f) =>
              parent == null ? f.parentId.isNull() : f.parentId.equals(parent),
        );
      final existing = await query.getSingleOrNull();
      parent =
          existing?.id ??
          await db
              .into(db.folders)
              .insert(
                FoldersCompanion.insert(name: name, parentId: Value(parent)),
              );
    }
    return parent;
  }

  bool _inUserFolder(String path) => path.startsWith(userFolder.path);

  static bool _hidden(File file) => _name(file).startsWith('.');

  static String _name(File file) => file.uri.pathSegments.last;

  /// drift stores DateTime in whole seconds.
  static DateTime _seconds(DateTime t) => DateTime.fromMillisecondsSinceEpoch(
    t.millisecondsSinceEpoch ~/ 1000 * 1000,
  );

  static Directory _dir(Directory parent, String name) =>
      Directory('${parent.path}${Platform.pathSeparator}$name');

  /// `dir/name`, or `dir/name (2).ext`, `(3)`, … if taken.
  static String _freePath(Directory dir, String name) {
    final dot = name.lastIndexOf('.');
    final (stem, ext) = dot > 0
        ? (name.substring(0, dot), name.substring(dot))
        : (name, '');
    var candidate = name;
    for (
      var n = 2;
      File('${dir.path}${Platform.pathSeparator}$candidate').existsSync();
      n++
    ) {
      candidate = '$stem ($n)$ext';
    }
    return '${dir.path}${Platform.pathSeparator}$candidate';
  }
}
