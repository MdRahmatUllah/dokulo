import 'dart:math' as math;

import 'package:opencv_dart/opencv_dart.dart' as cv;

import 'quad_detector.dart';

/// ID-1's proportions (85.6 × 54 mm) and its size at 300 dpi.
const idCardAspect = 85.6 / 54;
const idCardPixels = (1011, 638);

/// The card inside [quad], flattened to ID-1 at 300 dpi (DK-0340), landscape
/// whichever way it was held. Returns a new Mat the caller disposes. Like
/// everything here, call it off the UI isolate (OpenCV's own isolate).
cv.Mat cropIdCard(cv.Mat photo, Quad quad) {
  final flat = warpQuad(photo, quad);
  // Held upright: turn it to landscape, as the card reads.
  final landscape = flat.rows > flat.cols
      ? cv.rotate(flat, cv.ROTATE_90_CLOCKWISE)
      : flat;
  final out = cv.resize(landscape, idCardPixels, interpolation: cv.INTER_AREA);
  if (!identical(landscape, flat)) landscape.dispose();
  flat.dispose();
  return out;
}

/// Where the spine of an open book is in [spread]: an x in pixels, from the
/// darkest column band in the middle third (the gutter's shadow), refined
/// by the most vertical long Hough line near it (DK-0341). Off the UI
/// isolate.
int findSpine(cv.Mat spread) {
  final grey = spread.channels == 1
      ? spread.clone()
      : cv.cvtColor(spread, cv.COLOR_BGR2GRAY);
  try {
    final w = grey.cols, h = grey.rows;
    // The vertical projection profile: each column's mean brightness.
    final profile = cv.reduce(grey, 0, cv.REDUCE_AVG, dtype: cv.MatType.CV_32F);
    final from = w ~/ 3, to = 2 * w ~/ 3;
    final band = math.max(3, w ~/ 100);
    var best = from;
    var bestSum = double.infinity;
    for (var x = from; x < to - band; x++) {
      var sum = 0.0;
      for (var i = 0; i < band; i++) {
        sum += profile.atF32(0, i1: x + i);
      }
      if (sum < bestSum) {
        bestSum = sum;
        best = x + band ~/ 2;
      }
    }
    profile.dispose();
    // A long, near-vertical edge close to it wins (a crisp gutter line).
    final edges = cv.canny(grey, 50, 150);
    final lines = cv.HoughLinesP(
      edges,
      1,
      math.pi / 180,
      80,
      minLineLength: h * 0.5,
      maxLineGap: 20,
    );
    edges.dispose();
    var bestLine = -1.0;
    for (var i = 0; i < lines.rows; i++) {
      final v = lines.at<cv.Vec4i>(i, 0);
      final (x1, y1, x2, y2) = (v.val1, v.val2, v.val3, v.val4);
      final dx = (x2 - x1).abs(), dy = (y2 - y1).abs();
      if (dy == 0 || dx / dy > 0.05) continue; // within ~3° of vertical
      final x = (x1 + x2) / 2;
      if ((x - best).abs() > w * 0.05) continue;
      if (dy > bestLine) {
        bestLine = dy.toDouble();
        best = x.round();
      }
    }
    lines.dispose();
    return best;
  } finally {
    grey.dispose();
  }
}

/// The skew of text in [page] in degrees (positive: the lines rise to the
/// right), from the angle whose horizontal projection profile is sharpest,
/// searched over ±[range]°.
double textSkew(cv.Mat page, {double range = 8, double step = 0.5}) {
  final grey = page.channels == 1
      ? page.clone()
      : cv.cvtColor(page, cv.COLOR_BGR2GRAY);
  // Small and binary: ink is 255.
  final scale = 400 / math.max(grey.cols, grey.rows);
  final small = scale < 1
      ? cv.resize(grey, (
          (grey.cols * scale).round(),
          (grey.rows * scale).round(),
        ))
      : grey.clone();
  final (_, ink) = cv.threshold(
    small,
    0,
    255,
    cv.THRESH_BINARY_INV | cv.THRESH_OTSU,
  );
  grey.dispose();
  small.dispose();
  try {
    var bestAngle = 0.0, bestScore = -1.0;
    final centre = cv.Point2f(ink.cols / 2, ink.rows / 2);
    for (var a = -range; a <= range + 1e-9; a += step) {
      final m = cv.getRotationMatrix2D(centre, a, 1);
      final turned = cv.warpAffine(ink, m, (ink.cols, ink.rows));
      final rows = cv.reduce(
        turned,
        1,
        cv.REDUCE_SUM,
        dtype: cv.MatType.CV_32F,
      );
      // Sharp rows (text lines, then gaps) give a large variance.
      var mean = 0.0;
      for (var y = 0; y < rows.rows; y++) {
        mean += rows.atF32(y, i1: 0);
      }
      mean /= rows.rows;
      var variance = 0.0;
      for (var y = 0; y < rows.rows; y++) {
        final d = rows.atF32(y, i1: 0) - mean;
        variance += d * d;
      }
      if (variance > bestScore) {
        bestScore = variance;
        bestAngle = a;
      }
      for (final x in [m, turned, rows]) {
        x.dispose();
      }
    }
    // Rotating by +a straightens text skewed by -a.
    return -bestAngle;
  } finally {
    ink.dispose();
  }
}

/// [page] rotated by [degrees] about its centre (white fill outside).
cv.Mat rotated(cv.Mat page, double degrees) {
  final m = cv.getRotationMatrix2D(
    cv.Point2f(page.cols / 2, page.rows / 2),
    degrees,
    1,
  );
  final out = cv.warpAffine(
    page,
    m,
    (page.cols, page.rows),
    borderMode: cv.BORDER_CONSTANT,
    borderValue: cv.Scalar.all(255),
  );
  m.dispose();
  return out;
}

/// An open book's spread split at the spine into the left and the right
/// page, each deskewed (DK-0341; full curve dewarping is later). The Mats
/// are new; the caller disposes them. Off the UI isolate.
({cv.Mat left, cv.Mat right, int spine}) splitSpread(cv.Mat spread) {
  final spine = findSpine(spread);
  final leftRoi = spread.region(cv.Rect(0, 0, spine, spread.rows));
  final rightRoi = spread.region(
    cv.Rect(spine, 0, spread.cols - spine, spread.rows),
  );
  final left = rotated(leftRoi, -textSkew(leftRoi));
  final right = rotated(rightRoi, -textSkew(rightRoi));
  leftRoi.dispose();
  rightRoi.dispose();
  return (left: left, right: right, spine: spine);
}
