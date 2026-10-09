import 'dart:typed_data';
import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../components/dk_scan_button.dart';
import 'scanner_camera.dart';

part 'scan_session.g.dart';

/// A document's corners in a frame, clockwise from top-left, each 0–1 of the
/// frame's width and height (so the screen can draw it at any size).
typedef DetectedQuad = List<Offset>;

/// Finds the document in a preview frame. DK-0337 (OpenCV, both platforms)
/// and DK-0336 (Vision on iOS) provide the real one; until then nothing is
/// found and the user captures by hand.
typedef QuadDetector = Future<DetectedQuad?> Function(GreyFrame frame);

@riverpod
QuadDetector quadDetector(Ref ref) =>
    (_) async => null;

/// One captured page, as S2 reviews it.
class ScannedPage {
  const ScannedPage(this.jpeg, {this.quad});
  final Uint8List jpeg;

  /// The corners found at capture (S2's crop starts from them).
  final DetectedQuad? quad;
}

/// The pages of the scan in progress, shared by S1 and S2 (DK-0343).
@Riverpod(keepAlive: true)
class ScanSession extends _$ScanSession {
  @override
  List<ScannedPage> build() => const [];

  void add(ScannedPage page) => state = [...state, page];

  void clear() => state = const [];
}

/// The scanner's mode (the mode switcher; the Scan button's long press).
@riverpod
class ScanModeState extends _$ScanModeState {
  @override
  DkScanMode build() => DkScanMode.document;

  void set(DkScanMode mode) => state = mode;
}
