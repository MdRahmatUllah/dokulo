/// Layer 2 of Dokulo's five layers (see the README at the repo root).
library;

// The scan's page edits, for the app (it doesn't depend on doc_vision).
export 'package:doc_vision/doc_vision.dart' show Pt, ScanFilter;
export 'src/job_queue.dart';
export 'src/preflight.dart';
export 'src/registry.dart';
export 'src/scan_save.dart';
export 'src/signature_photo.dart';
export 'src/startup.dart';
export 'src/tool_job.dart';
export 'src/tools/compress_job.dart';
export 'src/tools/img2pdf_job.dart';
export 'src/tools/ocr_job.dart';
export 'src/tools/output_name.dart';

/// Its row in the Technology plan's "Stack at a glance" table.
const int docToolsLayer = 2;
