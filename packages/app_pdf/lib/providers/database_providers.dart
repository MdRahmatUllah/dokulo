import 'package:doc_core/doc_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_providers.g.dart';

/// The app's database, in app support (DK-0005). Kept alive: closing and
/// reopening it between screens would cost a file open each time. Tests
/// override it with `DokuloDatabase.memory()`.
@Riverpod(keepAlive: true)
DokuloDatabase appDatabase(Ref ref) {
  final db = DokuloDatabase.open(getApplicationSupportDirectory);
  ref.onDispose(db.close);
  return db;
}
