/// Layer 3 of Dokulo's five layers (see the README at the repo root).
library;

export 'src/db/database.dart';
export 'src/files/file_store.dart';
export 'src/pdf/pdf_engine.dart';
export 'src/pdf/compress/raster_fallback.dart';
export 'src/pdf/compress/size_target.dart';
export 'src/pdf/compress/strip_metadata.dart';
export 'src/pdf/ocr_text_layer.dart';
export 'src/pdf/pdf_compress.dart';
export 'src/pdf/pdf_structure.dart';
export 'src/pdf/pdfa_writer.dart';
export 'src/pdf/srgb2014_icc.dart';
export 'src/pdf/qpdf_service.dart';
export 'src/pdf/redact/detectors.dart';
export 'src/pdf/redact/pdf_redactor.dart';
export 'src/pdf/thumbnail_cache.dart';

/// Its row in the Technology plan's "Stack at a glance" table.
const int docCoreLayer = 3;
