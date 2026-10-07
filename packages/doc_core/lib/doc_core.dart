/// Layer 3 of Dokulo's five layers (see the README at the repo root).
library;

export 'src/db/database.dart';
export 'src/files/file_store.dart';
export 'src/pdf/pdf_engine.dart';
export 'src/pdf/pdf_structure.dart';
export 'src/pdf/thumbnail_cache.dart';

/// Its row in the Technology plan's "Stack at a glance" table.
const int docCoreLayer = 3;
