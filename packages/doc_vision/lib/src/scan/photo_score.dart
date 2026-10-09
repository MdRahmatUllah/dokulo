import 'dart:math' as math;
import 'dart:typed_data';

import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../ocr/ocr_engine.dart';
import '../ocr/pp_ocr.dart';
import 'quad_detector.dart';

/// A photo decoded for [documentScore]: its BGR pixels (for OCR) and the
/// page found in it, if any.
typedef ScoringImage = ({Raster raster, Quad? quad});

/// Decodes a JPEG or PNG (a library thumbnail) and looks for a page in it.
/// Null when the bytes are no image. OpenCV: call it on a worker isolate.
ScoringImage? decodeForScoring(Uint8List bytes) {
  final mat = cv.imdecode(bytes, cv.IMREAD_COLOR);
  try {
    if (mat.isEmpty) return null;
    return (
      // A copy: the Mat's buffer is freed below.
      raster: Raster(mat.cols, mat.rows, Uint8List.fromList(mat.data)),
      quad: detectQuad(mat)?.quad,
    );
  } finally {
    mat.dispose();
  }
}

/// A [documentScore] from here up is a document.
const documentThreshold = 0.5;

/// Width : height of the papers a document photo shows, either way up: A4
/// (and the other ISO sizes), US Letter, an ID card.
const _paperRatios = [1.414, 1.294, 1.586];

/// How much a photo looks like a document, 0–1 (DK-0362; no training):
///
/// - 55 %: how much of the photo is text ([words], from OCR), full marks
///   from 12 % of the area, and only with a few words (a sign is not a
///   document);
/// - 30 %: a page-like quad was found, full marks from 30 % of the photo;
/// - 15 %: that quad has a paper's proportions (A4, Letter, ID card) or a
///   receipt's (over 2 : 1).
///
/// So a screenshot of a text page (no quad) still reaches 0.55, and a
/// picture frame (a quad, no text) stays at 0.45.
/// ponytail: fixed weights; tune them on the labelled photo set.
double documentScore({
  required int width,
  required int height,
  required List<Word> words,
  Quad? quad,
}) {
  final textArea = words.fold(0.0, (a, w) => a + w.box.width * w.box.height);
  final text =
      (textArea / 0.12).clamp(0.0, 1.0) * (words.length / 8).clamp(0.0, 1.0);
  var page = 0.0, proportions = 0.0;
  if (quad != null) {
    page = (quad.area / (width * height) / 0.3).clamp(0.0, 1.0);
    double side(Pt a, Pt b) =>
        math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
    final w =
        (side(quad.topLeft, quad.topRight) +
            side(quad.bottomLeft, quad.bottomRight)) /
        2;
    final h =
        (side(quad.topLeft, quad.bottomLeft) +
            side(quad.topRight, quad.bottomRight)) /
        2;
    if (w > 0 && h > 0) {
      final ratio = math.max(w, h) / math.min(w, h);
      proportions =
          ratio > 2 || _paperRatios.any((r) => (ratio / r - 1).abs() < 0.12)
          ? 1
          : 0;
    }
  }
  return 0.55 * text + 0.3 * page + 0.15 * proportions;
}
