import 'package:drift/drift.dart';

import '../db/database.dart';
import '../pdf/pdf_engine.dart';

/// Keeps Files search's index in step with the files (DK-0270): every page's
/// text, from PDFium, into the FTS5 table `ocr_text`, and `files.has_text`
/// for the "no searchable text" banner and AI readiness. An OCR'd scan
/// carries its invisible text layer, so its OCR text comes out the same way.
///
/// A file is stale while `files.indexed_at` isn't its `modified`. Each file is
/// indexed in one transaction: an app killed mid-update leaves the old index
/// and the file still stale, and the next [catchUp] finishes it. After a
/// save: `FileStore.save`, `reconcile`, then [catchUp]; startup runs it too.
class TextIndexer {
  TextIndexer(this.db);

  final DokuloDatabase db;

  /// Files whose index doesn't match their current version.
  Future<List<FileEntry>> stale() =>
      (db.select(db.files)
            ..where(
              (f) => f.indexedAt.isNull() | f.indexedAt.isNotExp(f.modified),
            )
            ..orderBy([
              (f) => OrderingTerm.desc(f.modified),
            ])) // newest first: likely the one just saved
          .get();

  /// Indexes every stale file, one at a time; returns how many.
  Future<int> catchUp({
    String? Function(FileEntry file)? password,
    bool Function()? isCancelled,
  }) async {
    var done = 0;
    for (final file in await stale()) {
      if (isCancelled?.call() ?? false) break;
      await index(file, password: password?.call(file));
      done++;
    }
    return done;
  }

  /// Reads [file]'s text page by page and swaps it into the index.
  Future<void> index(FileEntry file, {String? password}) async {
    final pages = <(int, String)>[];
    if (file.path.toLowerCase().endsWith('.pdf')) {
      try {
        final count = (await PdfEngine.inspect(
          file.path,
          password: password,
        )).pageCount;
        for (var p = 0; p < count; p++) {
          final text = (await PdfEngine.pageText(
            file.path,
            p,
            password: password,
          )).text.trim();
          if (text.isNotEmpty) pages.add((p, text));
        }
      } on DocError {
        // Locked, damaged or gone: nothing to search; it isn't retried until
        // the file changes (a locked file is indexed when it's unlocked).
        pages.clear();
      }
    }
    await db.transaction(() async {
      await db.customStatement('DELETE FROM ocr_text WHERE file_id = ?', [
        file.id,
      ]);
      for (final (page, text) in pages) {
        await db.customInsert(
          'INSERT INTO ocr_text (file_id, page, page_text) VALUES (?, ?, ?)',
          variables: [Variable(file.id), Variable(page + 1), Variable(text)],
        );
      }
      await (db.update(db.files)..where((f) => f.id.equals(file.id))).write(
        FilesCompanion(
          hasText: Value(pages.isNotEmpty),
          indexedAt: Value(file.modified),
        ),
      );
    });
  }
}
