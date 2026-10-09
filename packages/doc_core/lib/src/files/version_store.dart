import 'dart:io';

import 'package:drift/drift.dart';

import '../db/database.dart';

/// Version history (DK-0277): before an edit in V2 or "Replace original"
/// overwrites a file, [save] keeps a copy of what it was. The newest [keep]
/// per file stay, and [purge] (at launch) drops any older than [maxAge].
/// Info → Versions lists them with Restore.
///
/// The `versions_keep_5` trigger only deletes rows, so [save] drops the
/// oldest itself first, files and rows together; [purge] also deletes copies
/// no row points to (a file deleted with its rows, a crash mid-save).
class VersionStore {
  VersionStore(this.db, this.directory, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  static const keep = 5;
  static const maxAge = Duration(days: 30);

  final DokuloDatabase db;

  /// In the sandbox (`<work>/versions`), never in the user folder.
  final Directory directory;
  final DateTime Function() _now;

  /// Copies file [fileId]'s current content into a new version.
  Future<Version> save(int fileId) async {
    final file = await (db.select(
      db.files,
    )..where((f) => f.id.equals(fileId))).getSingle();
    await directory.create(recursive: true);
    final now = _now();
    final copy = await File(file.path).copy(
      '${directory.path}${Platform.pathSeparator}'
      '${fileId}_${now.microsecondsSinceEpoch}.pdf',
    );
    return db.transaction(() async {
      final older = await (_newestFirst(
        fileId,
      )..limit(1 << 30, offset: keep - 1)).get();
      await _drop(older);
      return db
          .into(db.versions)
          .insertReturning(
            VersionsCompanion.insert(
              fileId: fileId,
              path: copy.path,
              createdAt: now,
            ),
          );
    });
  }

  /// The file's versions, newest first.
  Future<List<Version>> list(int fileId) => _newestFirst(fileId).get();

  /// Puts [version] back as the file's content. What the file was becomes a
  /// version itself, so a restore can be undone the same way; the restored
  /// copy leaves the list (its content is the file now).
  Future<void> restore(Version version) async {
    // Set the copy aside first: saving the current content may drop the
    // oldest version, and that may be the one being restored.
    final aside = await File(version.path).copy('${version.path}.restore');
    await save(version.fileId);
    final file = await (db.select(
      db.files,
    )..where((f) => f.id.equals(version.fileId))).getSingle();
    final restored = await aside.copy(file.path);
    await aside.delete();
    await (db.update(db.files)..where((f) => f.id.equals(file.id))).write(
      FilesCompanion(
        size: Value(await restored.length()),
        modified: Value(_now()),
      ),
    );
    await _drop([version]);
  }

  /// At launch: versions older than [maxAge] go, and copies no row points
  /// to. Returns how many copies were deleted.
  Future<int> purge() async {
    final expired =
        await (db.select(db.versions)..where(
              (v) => v.createdAt.isSmallerThanValue(_now().subtract(maxAge)),
            ))
            .get();
    await _drop(expired);
    var deleted = expired.length;
    if (!await directory.exists()) return deleted;
    final known = {for (final v in await db.select(db.versions).get()) v.path};
    await for (final entry in directory.list()) {
      if (entry is File && !known.contains(entry.path)) {
        await entry.delete();
        deleted++;
      }
    }
    return deleted;
  }

  SimpleSelectStatement<Versions, Version> _newestFirst(int fileId) =>
      db.select(db.versions)
        ..where((v) => v.fileId.equals(fileId))
        ..orderBy([
          (v) => OrderingTerm.desc(v.createdAt),
          (v) => OrderingTerm.desc(v.id),
        ]);

  Future<void> _drop(List<Version> versions) async {
    for (final v in versions) {
      final copy = File(v.path);
      if (await copy.exists()) await copy.delete();
      await (db.delete(db.versions)..where((r) => r.id.equals(v.id))).go();
    }
  }
}
