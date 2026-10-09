import 'package:drift/drift.dart';

import 'database.dart';

/// What the photo finder knows about one photo (`photo_finder_cache`).
typedef PhotoScore = ({
  String id,
  DateTime modified,
  double score,
  bool isDocument,
});

/// The photo finder's cache (DK-0362): one row per photo looked at, so a
/// scan resumes and a photo is only scored again when it changed. A negative
/// score is the user's own "Not a document", which a rescan keeps.
class PhotoFinderStore {
  PhotoFinderStore(this._db);
  final DokuloDatabase _db;

  /// The rows for [ids] (photos never scored are missing).
  Future<Map<String, PhotoScore>> lookup(List<String> ids) async => {
    for (final r in await (_db.select(
      _db.photoFinderCache,
    )..where((r) => r.assetId.isIn(ids))).get())
      r.assetId: (
        id: r.assetId,
        modified: r.modified,
        score: r.score,
        isDocument: r.isDocument,
      ),
  };

  Future<void> put(
    String id,
    DateTime modified,
    double score, {
    required bool isDocument,
  }) => _db
      .into(_db.photoFinderCache)
      .insertOnConflictUpdate(
        PhotoFinderCacheCompanion.insert(
          assetId: id,
          modified: modified,
          score: score,
          isDocument: isDocument,
        ),
      );

  /// The user's long press: not a document, for good.
  Future<void> notADocument(String id) =>
      (_db.update(
        _db.photoFinderCache,
      )..where((r) => r.assetId.equals(id))).write(
        const PhotoFinderCacheCompanion(
          isDocument: Value(false),
          score: Value(-1),
        ),
      );

  /// The photos that look like documents, newest first, with when they
  /// last changed (the results' month headers).
  Future<List<({String id, DateTime modified})>> documents() async => [
    for (final r
        in await (_db.select(_db.photoFinderCache)
              ..where((r) => r.isDocument.equals(true))
              ..orderBy([(r) => OrderingTerm.desc(r.modified)]))
            .get())
      (id: r.assetId, modified: r.modified),
  ];
}
