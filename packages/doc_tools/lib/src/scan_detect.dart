import 'dart:isolate';
import 'dart:typed_data';

import 'package:doc_vision/doc_vision.dart';

/// A page's corners in a camera frame, clockwise from top-left, each as
/// fractions (0–1) of the frame, with the detector's confidence.
typedef FramePage = ({List<({double x, double y})> corners, double score});

/// The scanner's page detection for one preview frame (S1, DK-0337): the
/// frame's grey (Y) plane through doc_vision's OpenCV detector, on a worker
/// isolate (the UI isolate never calls native code). Null: no page.
/// ponytail: one short-lived isolate per frame; S1 asks for the next frame
/// only when this one is done. A long-lived worker if frames queue up.
Future<FramePage?> detectFramePage(
  Uint8List grey,
  int width,
  int height, {
  int? rowStride,
}) => Isolate.run(() {
  final found = detectQuadInGrey(grey, width, height, rowStride: rowStride);
  if (found == null) return null;
  return (
    corners: [
      for (final p in found.quad.corners) (x: p.x / width, y: p.y / height),
    ],
    score: found.score,
  );
});
