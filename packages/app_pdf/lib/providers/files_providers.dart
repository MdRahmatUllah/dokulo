import 'dart:io';
import 'dart:ui' as ui;

import 'package:doc_core/doc_core.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'database_providers.dart';
import 'prefs_providers.dart';

part 'files_providers.g.dart';

/// F1's sort (UI spec §16.1): date modified (default) · name · size · date
/// created, ascending or descending.
enum FileSort { modified, name, size, created }

/// What F1 shows and how; kept in [Prefs] per user.
class FilesView {
  const FilesView({
    this.grid = false,
    this.sort = FileSort.modified,
    this.descending = true,
  });

  final bool grid;
  final FileSort sort;
  final bool descending;

  static FilesView from(Map<String, Object?> prefs) => FilesView(
    grid: prefs['files.grid'] == true,
    sort: FileSort.values.asNameMap()[prefs['files.sort']] ?? FileSort.modified,
    descending: prefs['files.descending'] != false,
  );

  int compare(FileEntry a, FileEntry b) {
    final byKey = switch (sort) {
      FileSort.modified => a.modified.compareTo(b.modified),
      FileSort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      FileSort.size => a.size.compareTo(b.size),
      FileSort.created => a.created.compareTo(b.created),
    };
    return descending ? -byKey : byKey;
  }
}

@riverpod
FilesView filesView(Ref ref) =>
    FilesView.from(ref.watch(prefsProvider).value ?? const {});

/// A folder and how many files it holds (not counting deleted ones).
typedef FolderCount = ({Folder folder, int files});

/// The folders in [parent] (null: the root), by name, live.
@riverpod
Stream<List<FolderCount>> folders(Ref ref, int? parent) {
  final db = ref.watch(appDatabaseProvider);
  return db
      .customSelect(
        'SELECT f.*, (SELECT COUNT(*) FROM files x WHERE x.folder_id = f.id '
        'AND x.id NOT IN (SELECT file_id FROM trash)) AS n '
        'FROM folders f WHERE f.parent_id IS ? ORDER BY f.name COLLATE NOCASE',
        variables: [Variable<int>(parent)],
        readsFrom: {db.folders, db.files, db.trash},
      )
      .watch()
      .map(
        (rows) => [
          for (final r in rows)
            (folder: db.folders.map(r.data), files: r.read<int>('n')),
        ],
      );
}

/// The files in [folder] (null: the root), not deleted, live, in F1's sort.
@riverpod
Stream<List<FileEntry>> filesIn(Ref ref, int? folder) {
  final db = ref.watch(appDatabaseProvider);
  final view = ref.watch(filesViewProvider);
  final query = db.select(db.files)
    ..where(
      (f) =>
          (folder == null ? f.folderId.isNull() : f.folderId.equals(folder)) &
          f.id.isNotInQuery(
            db.selectOnly(db.trash)..addColumns([db.trash.fileId]),
          ),
    );
  return query.watch().map((rows) => rows..sort(view.compare));
}

/// How many files are in Recently deleted, for F1's special row.
@riverpod
Stream<int> trashCount(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final count = db.trash.fileId.count();
  return (db.selectOnly(
    db.trash,
  )..addColumns([count])).watchSingle().map((row) => row.read(count) ?? 0);
}

/// Page thumbnails on disk, in the cache directory (the OS may clear it).
@Riverpod(keepAlive: true)
Future<ThumbnailCache> thumbnailCache(Ref ref) async => ThumbnailCache(
  Directory(
    '${(await getApplicationCacheDirectory()).path}'
    '${Platform.pathSeparator}thumbnails',
  ),
);

/// A file's first page, small, for its card (F1, Home's recents): rendered
/// on PDFium's worker once per file version and cached on disk.
@riverpod
Future<ui.Image> fileThumbnail(Ref ref, String path, int width) async {
  final cache = await ref.watch(thumbnailCacheProvider.future);
  final page = await cache.thumbnail(path, 0, width: width);
  final buffer = await ui.ImmutableBuffer.fromUint8List(page.bgra);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: page.width,
    height: page.height,
    pixelFormat: ui.PixelFormat.bgra8888,
  );
  final codec = await descriptor.instantiateCodec();
  final image = (await codec.getNextFrame()).image;
  ref.onDispose(image.dispose);
  return image;
}
