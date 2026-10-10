import 'package:doc_core/doc_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../providers/database_providers.dart';

part 'viewer_providers.g.dart';

/// The file V1 shows, by its row id in the file index (`/viewer/:fileId`).
@riverpod
Future<FileEntry> viewerFile(Ref ref, int fileId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.files)..where((f) => f.id.equals(fileId))).getSingle();
}

/// Whether a PDF opens (V1's locked and damaged states, DK-0301, DK-0305).
enum ViewerOpen { ok, locked, damaged }

/// Opens [path] once with [password] to see whether V1 can show it.
@riverpod
Future<ViewerOpen> viewerOpen(Ref ref, String path, {String? password}) async {
  try {
    await PdfEngine.inspect(path, password: password);
    return ViewerOpen.ok;
  } on DocError catch (e) {
    return e.kind == DocErrorKind.locked
        ? ViewerOpen.locked
        : ViewerOpen.damaged;
  }
}

/// Whether a PDF has fields to fill (V1's form banner, DK-1090): an
/// AcroForm with at least one field (a flattened form keeps its empty
/// dictionary; XFA can't be filled on phones).
@riverpod
Future<bool> viewerHasForm(Ref ref, String path, {String? password}) async {
  try {
    if (await PdfForms.kind(path, password: password) != PdfFormKind.acroForm) {
      return false;
    }
    return (await PdfForms.fields(path, password: password)).isNotEmpty;
  } on DocError {
    return false;
  }
}
