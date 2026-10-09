/// Layer 4 of Dokulo's five layers (see the README at the repo root).
library;

export 'src/ocr/flutter_onnx_runner.dart';
export 'src/ocr/ocr_engine.dart';
export 'src/ocr/pp_ocr.dart';
export 'src/scan/quad_detector.dart';
export 'src/scan/scan_filters.dart';

/// Its row in the Technology plan's "Stack at a glance" table.
const int docVisionLayer = 4;
