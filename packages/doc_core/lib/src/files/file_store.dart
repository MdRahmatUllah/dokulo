import 'dart:io';

import 'package:drift/drift.dart';

import '../db/database.dart';
import '../pdf/pdf_engine.dart';

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

  /// Renames file [id] to [stem] plus its extension (DK-0272): characters
  /// no file system takes (\ / : * ? " < > |) are dropped, the extension is
  /// kept. A name another file in the folder has throws [FileNameException].
  Future<void> renameFile(DokuloDatabase db, int id, String stem) async {
    final row = await _file(db, id);
    final dot = row.name.lastIndexOf('.');
    final ext = dot > 0 ? row.name.substring(dot) : '';
    final clean = stem.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
    if (clean.isEmpty || clean == '.' || clean == '..') {
      throw const FileNameException(FileNameProblem.invalid);
    }
    final name = '$clean$ext';
    if (name == row.name) return;
    final dir = File(row.path).parent;
    final target = File('${dir.path}${Platform.pathSeparator}$name');
    final sameIgnoringCase = name.toLowerCase() == row.name.toLowerCase();
    if (!sameIgnoringCase && await target.exists()) {
      throw const FileNameException(FileNameProblem.taken);
    }
    await File(row.path).rename(target.path);
    await (db.update(db.files)..where((f) => f.id.equals(id))).write(
      FilesCompanion(path: Value(target.path), name: Value(name)),
    );
  }

  /// A copy of file [id] next to it, "{name} (2).pdf" or the next free
  /// number (DK-0276). Returns the copy's row id; [deleteCopy] undoes it.
  Future<int> duplicateFile(DokuloDatabase db, int id) async {
    final row = await _file(db, id);
    final dir = File(row.path).parent;
    final copy = await File(row.path).copy(_freePath(dir, row.name));
    final stat = await copy.stat();
    return db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            path: copy.path,
            name: _name(copy),
            size: stat.size,
            pages: Value(row.pages),
            created: stat.modified,
            modified: stat.modified,
            hasText: Value(row.hasText),
            encrypted: Value(row.encrypted),
            folderId: Value(row.folderId),
          ),
        );
  }

  /// Takes a [duplicateFile] back: the copy and its row go.
  Future<void> deleteCopy(DokuloDatabase db, int id) async {
    final row = await _file(db, id);
    final file = File(row.path);
    if (await file.exists()) await file.delete();
    await (db.delete(db.files)..where((f) => f.id.equals(id))).go();
  }

  /// Moves file [id] into folder [folder] (null: the root) on disk and in
  /// the index (DK-0274), under a free name there. Returns the folder it was
  /// in, for Undo (move it back).
  Future<int?> moveFile(DokuloDatabase db, int id, int? folder) async {
    final row = await _file(db, id);
    if (row.folderId == folder) return folder;
    await _relocate(db, row, folder);
    return row.folderId;
  }

  /// Recently deleted (DK-0271 Delete): the file stays on disk until the
  /// trash is emptied or purged; [restoreFromTrash] takes it back.
  Future<void> trashFile(DokuloDatabase db, int id, {DateTime? now}) => db
      .into(db.trash)
      .insertOnConflictUpdate(
        TrashCompanion.insert(
          fileId: Value(id),
          deletedAt: now ?? DateTime.now(),
        ),
      );

  /// Takes file [id] out of Recently deleted, back to its folder (DK-0278);
  /// if that folder was deleted meanwhile, to the root.
  Future<void> restoreFromTrash(DokuloDatabase db, int id) async {
    final row = await _file(db, id);
    final orphan =
        row.folderId == null && File(row.path).parent.path != userFolder.path;
    if (orphan && await File(row.path).exists()) {
      await _relocate(db, row, null);
    }
    await (db.delete(db.trash)..where((t) => t.fileId.equals(id))).go();
  }

  /// Deletes file [id] for good (DK-0278): from disk and from the index
  /// (its trash row goes with it).
  Future<void> deleteForever(DokuloDatabase db, int id) async {
    final row = await _file(db, id);
    final file = File(row.path);
    if (await file.exists()) await file.delete();
    await (db.delete(db.files)..where((f) => f.id.equals(id))).go();
  }

  /// [row]'s file into folder [folder] (null: the root), under a free name.
  Future<void> _relocate(DokuloDatabase db, FileEntry row, int? folder) async {
    final dir = await folderDirectory(db, folder);
    await dir.create(recursive: true);
    final target = _freePath(dir, row.name);
    // Rename where it can, copy-and-delete across volumes.
    try {
      await File(row.path).rename(target);
    } on FileSystemException {
      await File(row.path).copy(target);
      await File(row.path).delete();
    }
    await (db.update(db.files)..where((f) => f.id.equals(row.id))).write(
      FilesCompanion(
        path: Value(target),
        name: Value(_name(File(target))),
        folderId: Value(folder),
      ),
    );
  }

  Future<FileEntry> _file(DokuloDatabase db, int id) =>
      (db.select(db.files)..where((f) => f.id.equals(id))).getSingle();

  /// "Open a file" from the system picker or another app (DK-0241): a copy
  /// of [source] in the user folder (under a free name; the original stays
  /// where it was) and its row, so Files, Recent and V1 find it. Returns the
  /// row's id.
  Future<int> importToUserFolder(DokuloDatabase db, File source) async {
    await userFolder.create(recursive: true);
    final copy = await source.copy(_freePath(userFolder, _name(source)));
    final stat = await copy.stat();
    return db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            path: copy.path,
            name: _name(copy),
            size: stat.size,
            created: stat.modified,
            modified: stat.modified,
          ),
        );
  }

  /// A new folder named [name] in folder [parent] (null: the root): the
  /// directory in the user folder and its row. Throws [FolderNameException]
  /// for an empty name, one with a path separator, or one already there
  /// (case-insensitive, as both phones' file systems compare names).
  Future<int> createFolder(
    DokuloDatabase db,
    String name, {
    int? parent,
  }) async {
    final trimmed = _checkName(name);
    final siblings =
        await (db.select(db.folders)..where(
              (f) => parent == null
                  ? f.parentId.isNull()
                  : f.parentId.equals(parent),
            ))
            .get();
    final base = await folderDirectory(db, parent);
    if (siblings.any((f) => f.name.toLowerCase() == trimmed.toLowerCase()) ||
        await _dir(base, trimmed).exists()) {
      throw const FolderNameException(FolderNameProblem.taken);
    }
    await _dir(base, trimmed).create(recursive: true);
    return (await _folderId(db, _dir(base, trimmed)))!;
  }

  /// Renames folder [id] (DK-0262): the directory, its row, and the path of
  /// every file under it. A taken or invalid name throws
  /// [FolderNameException], as [createFolder] does.
  Future<void> renameFolder(DokuloDatabase db, int id, String name) async {
    final row = await (db.select(
      db.folders,
    )..where((f) => f.id.equals(id))).getSingle();
    final trimmed = _checkName(name);
    if (trimmed == row.name) return;
    final siblings =
        await (db.select(db.folders)..where(
              (f) => row.parentId == null
                  ? f.parentId.isNull()
                  : f.parentId.equals(row.parentId!),
            ))
            .get();
    final old = await folderDirectory(db, id);
    final renamed = _dir(old.parent, trimmed);
    final sameIgnoringCase = trimmed.toLowerCase() == row.name.toLowerCase();
    if (siblings.any(
          (f) => f.id != id && f.name.toLowerCase() == trimmed.toLowerCase(),
        ) ||
        (!sameIgnoringCase && await renamed.exists())) {
      throw const FolderNameException(FolderNameProblem.taken);
    }
    if (await old.exists()) await old.rename(renamed.path);
    final prefix = '${old.path}${Platform.pathSeparator}';
    await db.transaction(() async {
      await (db.update(db.folders)..where((f) => f.id.equals(id))).write(
        FoldersCompanion(name: Value(trimmed)),
      );
      for (final f in await db.select(db.files).get()) {
        if (!f.path.startsWith(prefix)) continue;
        await (db.update(db.files)..where((x) => x.id.equals(f.id))).write(
          FilesCompanion(
            path: Value(
              '${renamed.path}${Platform.pathSeparator}'
              '${f.path.substring(prefix.length)}',
            ),
          ),
        );
      }
    });
  }

  /// Deletes folder [id] and the folders in it (DK-0262). Their files go to
  /// Recently deleted (still on disk until the trash is emptied or purged);
  /// an empty folder's directory goes at once. Returns how many files moved
  /// to the trash.
  Future<int> deleteFolder(DokuloDatabase db, int id, {DateTime? now}) async {
    final dir = await folderDirectory(db, id);
    final files = await _filesInTree(db, id);
    await db.transaction(() async {
      for (final f in files) {
        await db
            .into(db.trash)
            .insertOnConflictUpdate(
              TrashCompanion.insert(
                fileId: Value(f.id),
                deletedAt: now ?? DateTime.now(),
              ),
            );
      }
      // The files keep their paths; their folder rows go (folder_id SET
      // NULL), the subfolders with them (ON DELETE CASCADE).
      await (db.delete(db.folders)..where((f) => f.id.equals(id))).go();
    });
    if (files.isEmpty && await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } on FileSystemException {
        // A file the index didn't know: the directory stays; reconcile sees it.
      }
    }
    return files.length;
  }

  /// How many files folder [id] and the folders in it hold, deleted ones
  /// left out (the delete confirmation says it).
  Future<int> countFilesInTree(DokuloDatabase db, int id) async {
    final trashed = {for (final t in await db.select(db.trash).get()) t.fileId};
    return (await _filesInTree(
      db,
      id,
    )).where((f) => !trashed.contains(f.id)).length;
  }

  Future<List<FileEntry>> _filesInTree(DokuloDatabase db, int id) async {
    final ids = <int>{id};
    for (var frontier = {id}; frontier.isNotEmpty;) {
      final children = await (db.select(
        db.folders,
      )..where((f) => f.parentId.isIn(frontier))).get();
      frontier = {for (final c in children) c.id}..removeAll(ids);
      ids.addAll(frontier);
    }
    return (db.select(db.files)..where((f) => f.folderId.isIn(ids))).get();
  }

  /// Where folder [id] is on disk (null: the user folder).
  Future<Directory> folderDirectory(DokuloDatabase db, int? id) async {
    final names = <String>[];
    for (var at = id; at != null;) {
      final row = await (db.select(
        db.folders,
      )..where((f) => f.id.equals(at!))).getSingle();
      names.insert(0, row.name);
      at = row.parentId;
    }
    return names.fold<Directory>(userFolder, _dir);
  }

  /// The folder of [path] inside the user folder ("Taxes", "Work/2026" with
  /// the platform's separator),
  /// or null when it is the user folder itself or outside it (the inbox,
  /// temp): a tool's result is saved next to its input.
  String? subfolderOf(String path) {
    if (!_inUserFolder(path)) return null;
    final parent = File(path).parent.path;
    if (parent.length <= userFolder.path.length) return null;
    return parent.substring(userFolder.path.length + 1);
  }

  /// [save]s a tool's [output] and adds it to the index, with its page
  /// count when it is a PDF (T3's Save, DK-0379).
  Future<FileEntry> saveIndexed(
    DokuloDatabase db,
    File output, {
    required String name,
    String? subfolder,
  }) async {
    final saved = await save(output, name: name, subfolder: subfolder);
    final stat = await saved.stat();
    final pages = saved.path.toLowerCase().endsWith('.pdf')
        ? (await PdfEngine.inspect(saved.path)).pageCount
        : 0;
    final id = await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            path: saved.path,
            name: _name(saved),
            size: stat.size,
            pages: Value(pages),
            created: stat.changed,
            modified: stat.modified,
            folderId: Value(await _folderId(db, saved.parent)),
          ),
        );
    return (db.select(db.files)..where((f) => f.id.equals(id))).getSingle();
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

  /// A folder name without spaces around it; empty, dot and path names throw.
  static String _checkName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty ||
        trimmed == '.' ||
        trimmed == '..' ||
        trimmed.contains('/') ||
        trimmed.contains(r'\')) {
      throw const FolderNameException(FolderNameProblem.invalid);
    }
    return trimmed;
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

enum FolderNameProblem { invalid, taken }

class FolderNameException implements Exception {
  const FolderNameException(this.problem);
  final FolderNameProblem problem;
  @override
  String toString() => 'FolderNameException: ${problem.name}';
}

enum FileNameProblem { invalid, taken }

class FileNameException implements Exception {
  const FileNameException(this.problem);
  final FileNameProblem problem;
  @override
  String toString() => 'FileNameException: ${problem.name}';
}
