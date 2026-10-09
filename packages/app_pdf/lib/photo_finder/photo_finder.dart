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

/// The phone's photo library, behind an interface so the finder can be
/// tested (DK-0362).
abstract interface class PhotoLibrary {
  /// Asks for access (the system prompt the first time). False: none.
  Future<bool> requestAccess();

  /// How many photos there are.
  Future<int> count();

  /// Photos [start] to [end], newest first.
  Future<List<LibraryPhoto>> range(int start, int end);

  /// A small JPEG of the photo (the long side about [size] px), or null.
  Future<Uint8List?> thumbnail(String id, {int size});
}

/// [PhotoLibrary] on `photo_manager` 3.12.0 (images only).
class PluginPhotoLibrary implements PhotoLibrary {
  const PluginPhotoLibrary();

  @override
  Future<bool> requestAccess() async =>
      (await PhotoManager.requestPermissionExtend()).hasAccess;

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

  @override
  Future<Uint8List?> thumbnail(String id, {int size = 320}) async {
    final asset = await AssetEntity.fromId(id);
    return asset?.thumbnailDataWithSize(
      ThumbnailSize.square(size),
      quality: 80,
    );
  }
}

@Riverpod(keepAlive: true)
PhotoLibrary photoLibrary(Ref ref) => const PluginPhotoLibrary();

/// How much a thumbnail looks like a document, 0–1 (doc_vision: text area +
/// a page quad + page proportions). Runs off the UI isolate.
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
  });

  final int scanned, total;
  final bool running;

  /// The photos that look like documents, best first.
  final List<String> found;

  double get progress => total == 0 ? 0 : scanned / total;

  PhotoFinderState copyWith({
    int? scanned,
    int? total,
    bool? running,
    List<String>? found,
  }) => PhotoFinderState(
    scanned: scanned ?? this.scanned,
    total: total ?? this.total,
    running: running ?? this.running,
    found: found ?? this.found,
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

  /// Scans the library (or the rest of it). Returns false without access.
  Future<bool> scan({int pageSize = 50}) async {
    if (state.running) return true;
    final library = ref.read(photoLibraryProvider);
    if (!await library.requestAccess()) return false;
    final score = ref.read(documentScorerProvider);
    _cancelled = false;
    final total = await library.count();
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
          final cached = known[p.id];
          // Unchanged since it was scored, or the user's own "Not a document".
          if (cached == null ||
              (!cached.modified.isAtSameMomentAs(p.modified) &&
                  cached.score >= 0)) {
            final thumb = await library.thumbnail(p.id);
            final s = thumb == null ? 0.0 : await score(thumb);
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
    } finally {
      state = state.copyWith(running: false, found: await _found());
    }
    return true;
  }

  /// Stops a running scan after the photo in hand (what is scored is kept).
  void cancel() => _cancelled = true;

  /// The user's long press: not a document, for good (a negative score
  /// marks the user's choice, which a rescan never overrides).
  Future<void> notADocument(String id) async {
    await _store.notADocument(id);
    state = state.copyWith(found: [...state.found]..remove(id));
  }

  /// Loads the results of earlier scans (Home's scanning card, the grid).
  Future<void> load() async => state = state.copyWith(found: await _found());

  Future<List<String>> _found() => _store.documents();
}
