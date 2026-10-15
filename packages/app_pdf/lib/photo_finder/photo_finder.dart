import 'dart:async';
import 'dart:typed_data';

import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/database_providers.dart';

part 'photo_finder.g.dart';

/// One photo in the library: an id the library knows it by, and when it
/// last changed (a changed photo is scored again).
typedef LibraryPhoto = ({String id, DateTime modified});

/// A photo the finder found: its id and when it was taken (the results'
/// month headers).
typedef FoundPhoto = ({String id, DateTime taken});

/// What the user allowed (UI spec §19.5).
enum PhotoAccess {
  /// The whole library.
  full,

  /// Only the photos the user picked (iOS 14+, Android 14+).
  limited,

  /// None; only the system Settings can change it now.
  denied,
}

/// The phone's photo library, behind an interface so the finder can be
/// tested (DK-0362).
abstract interface class PhotoLibrary {
  /// Asks for access (the system prompt the first time).
  Future<PhotoAccess> requestAccess();

  /// The app's page in the system Settings.
  Future<void> openSettings();

  /// Limited access: the system picker to share more photos.
  Future<void> selectMore();

  /// How many photos there are.
  Future<int> count();

  /// Photos [start] to [end], newest first.
  Future<List<LibraryPhoto>> range(int start, int end);

  /// A small JPEG of the photo (the long side about [size] px); null when
  /// it isn't on the phone (in iCloud only: fetching it would go online).
  Future<Uint8List?> thumbnail(String id, {int size});

  /// When each of [ids] was taken; photos gone from the library are left
  /// out.
  Future<Map<String, DateTime>> taken(List<String> ids);

  /// The photo itself and its file name, for converting; null when it
  /// isn't on the phone.
  Future<({Uint8List bytes, String name})?> original(String id);
}

/// [PhotoLibrary] on `photo_manager` 3.12.0 (images only). Its thumbnail
/// and file calls would fetch from iCloud, so photos that aren't on the
/// phone are skipped (offline).
class PluginPhotoLibrary implements PhotoLibrary {
  const PluginPhotoLibrary();

  @override
  Future<PhotoAccess> requestAccess() async =>
      switch (await PhotoManager.requestPermissionExtend()) {
        PermissionState.authorized => PhotoAccess.full,
        PermissionState.limited => PhotoAccess.limited,
        _ => PhotoAccess.denied,
      };

  @override
  Future<void> openSettings() => PhotoManager.openSetting();

  @override
  Future<void> selectMore() => PhotoManager.presentLimited();

  @override
  Future<int> count() => PhotoManager.getAssetCount(type: RequestType.image);

  @override
  Future<List<LibraryPhoto>> range(int start, int end) async => [
    for (final a in await PhotoManager.getAssetListRange(
      start: start,
      end: end,
      type: RequestType.image,
    ))
      (id: a.id, modified: a.modifiedDateTime),
  ];

  Future<AssetEntity?> _local(String id) async {
    final asset = await AssetEntity.fromId(id);
    if (asset == null || !await asset.isLocallyAvailable()) return null;
    return asset;
  }

  @override
  Future<Uint8List?> thumbnail(String id, {int size = 320}) async =>
      (await _local(id))
          ?.thumbnailDataWithSize(ThumbnailSize.square(size), quality: 80);

  @override
  Future<Map<String, DateTime>> taken(List<String> ids) async => {
    for (final id in ids)
      if (await AssetEntity.fromId(id) case final a?) id: a.createDateTime,
  };

  @override
  Future<({Uint8List bytes, String name})?> original(String id) async {
    final asset = await _local(id);
    final bytes = await asset?.originBytes;
    if (asset == null || bytes == null) return null;
    final title = await asset.titleAsync;
    return (bytes: bytes, name: title.isEmpty ? '$id.jpg' : title);
  }
}

@Riverpod(keepAlive: true)
PhotoLibrary photoLibrary(Ref ref) => const PluginPhotoLibrary();

/// How much a thumbnail looks like a document, 0–1 (doc_vision: text area +
/// a page quad + page proportions), on doc_tools' scoring worker isolate.
typedef DocumentScorer = Future<double> Function(Uint8List jpeg);

/// The finder's scorer: doc_tools' [DocumentPhotoScorer].
@Riverpod(keepAlive: true)
DocumentScorer documentScorer(Ref ref) {
  final scorer = DocumentPhotoScorer();
  ref.onDispose(scorer.close);
  return scorer.call;
}

/// Where a scan of the library stands.
class PhotoFinderState {
  const PhotoFinderState({
    this.scanned = 0,
    this.total = 0,
    this.running = false,
    this.found = const [],
    this.access,
  });

  final int scanned, total;
  final bool running;

  /// The photos that look like documents, newest first.
  final List<FoundPhoto> found;

  /// What the last scan was allowed; null before one.
  final PhotoAccess? access;

  double get progress => total == 0 ? 0 : scanned / total;

  PhotoFinderState copyWith({
    int? scanned,
    int? total,
    bool? running,
    List<FoundPhoto>? found,
    PhotoAccess? access,
  }) => PhotoFinderState(
    scanned: scanned ?? this.scanned,
    total: total ?? this.total,
    running: running ?? this.running,
    found: found ?? this.found,
    access: access ?? this.access,
  );
}

/// Find documents in photos (DK-0362): goes through the library newest
/// first, scores each thumbnail and keeps the result in drift
/// (`photo_finder_cache`), so a scan resumes after the app was killed and a
/// photo is only scored again when it changed. "Not a document" from the
/// user is remembered and never overridden. No network: the scorer and the
/// thumbnails are on the phone.
@Riverpod(keepAlive: true)
class PhotoFinder extends _$PhotoFinder {
  var _cancelled = false;

  @override
  PhotoFinderState build() => const PhotoFinderState();

  PhotoFinderStore get _store =>
      PhotoFinderStore(ref.read(appDatabaseProvider));

  /// Scans the library (or the rest of it). Returns what was allowed; with
  /// [PhotoAccess.denied] nothing runs.
  Future<PhotoAccess> scan({int pageSize = 50}) async {
    final library = ref.read(photoLibraryProvider);
    if (state.running) return state.access ?? PhotoAccess.full;
    final access = await library.requestAccess();
    state = state.copyWith(access: access);
    if (access == PhotoAccess.denied) return access;
    final score = ref.read(documentScorerProvider);
    _cancelled = false;
    final total = await library.count();
    final seen = <String>{};
    state = state.copyWith(running: true, total: total, scanned: 0);
    try {
      for (var start = 0; start < total && !_cancelled; start += pageSize) {
        final photos = await library.range(
          start,
          (start + pageSize).clamp(0, total),
        );
        final known = await _store.lookup([for (final p in photos) p.id]);
        for (final p in photos) {
          if (_cancelled) break;
          seen.add(p.id);
          final cached = known[p.id];
          // Unchanged since it was scored, or the user's own "Not a document".
          if (cached == null ||
              (!cached.modified.isAtSameMomentAs(p.modified) &&
                  cached.score >= 0)) {
            var s = 0.0;
            try {
              final thumb = await library.thumbnail(p.id);
              if (thumb != null) s = await score(thumb);
            } on Object {
              // Deleted meanwhile, unreadable, OCR failed: not a document,
              // and the scan goes on (tried again once the photo changes).
            }
            await _store.put(
              p.id,
              p.modified,
              s,
              isDocument: s >= documentThreshold,
            );
          }
          state = state.copyWith(scanned: state.scanned + 1);
        }
      }
      // A whole scan saw every photo: rows of photos gone since go too.
      if (!_cancelled) await _store.prune(seen);
    } finally {
      state = state.copyWith(running: false, found: await _found());
    }
    return access;
  }

  /// Stops a running scan after the photo in hand (what is scored is kept).
  void cancel() => _cancelled = true;

  /// The user's long press: not a document, for good (a negative score
  /// marks the user's choice, which a rescan never overrides).
  Future<void> notADocument(String id) async {
    await _store.notADocument(id);
    state = state.copyWith(
      found: [
        for (final p in state.found)
          if (p.id != id) p,
      ],
    );
  }

  /// Loads the results of earlier scans (Home's scanning card, the grid).
  Future<void> load() async => state = state.copyWith(found: await _found());

  /// The documents still in the library, newest taken first.
  Future<List<FoundPhoto>> _found() async {
    final rows = await _store.documents();
    final taken = await ref.read(photoLibraryProvider).taken([
      for (final r in rows) r.id,
    ]);
    return [
      for (final r in rows)
        if (taken[r.id] case final t?) (id: r.id, taken: t),
    ]..sort((a, b) => b.taken.compareTo(a.taken));
  }
}
