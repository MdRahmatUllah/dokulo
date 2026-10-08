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
