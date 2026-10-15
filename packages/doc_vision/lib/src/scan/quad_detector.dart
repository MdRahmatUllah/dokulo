import 'dart:math' as math;
import 'dart:typed_data';

import 'package:opencv_dart/opencv_dart.dart' as cv;

/// A point in image pixels.
typedef Pt = ({double x, double y});

/// A document's four corners in image pixels, clockwise from top-left
/// (DK-0337).
class Quad {
  const Quad(this.topLeft, this.topRight, this.bottomRight, this.bottomLeft);

  final Pt topLeft, topRight, bottomRight, bottomLeft;

  List<Pt> get corners => [topLeft, topRight, bottomRight, bottomLeft];

  /// The quad with every coordinate multiplied by [s].
  Quad scaled(double s) {
    Pt m(Pt p) => (x: p.x * s, y: p.y * s);
    return Quad(m(topLeft), m(topRight), m(bottomRight), m(bottomLeft));
  }

  /// The quad's area (shoelace).
  double get area {
    final c = corners;
    var sum = 0.0;
    for (var i = 0; i < 4; i++) {
      final a = c[i], b = c[(i + 1) % 4];
      sum += a.x * b.y - b.x * a.y;
    }
    return sum.abs() / 2;
  }

  /// The largest distance any corner moved from [other]'s.
  double maxCornerShift(Quad other) {
    var m = 0.0;
    for (var i = 0; i < 4; i++) {
      final a = corners[i], b = other.corners[i];
      m = math.max(
        m,
        math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2)),
      );
    }
    return m;
  }

  /// Orders four arbitrary points clockwise from the top-left one (the
  /// smallest x + y), as the warp and the UI expect.
  factory Quad.ordered(List<Pt> pts) {
    assert(pts.length == 4);
    final cx = pts.map((p) => p.x).reduce((a, b) => a + b) / 4;
    final cy = pts.map((p) => p.y).reduce((a, b) => a + b) / 4;
    final sorted = [...pts]
      ..sort(
        (a, b) => math
            .atan2(a.y - cy, a.x - cx)
            .compareTo(math.atan2(b.y - cy, b.x - cx)),
      );
    // atan2 sorts clockwise on screen (y grows down); rotate so the
    // top-left corner comes first.
    var start = 0;
    for (var i = 1; i < 4; i++) {
      if (sorted[i].x + sorted[i].y < sorted[start].x + sorted[start].y) {
        start = i;
      }
    }
    final c = [for (var i = 0; i < 4; i++) sorted[(start + i) % 4]];
    return Quad(c[0], c[1], c[2], c[3]);
  }

  @override
  String toString() =>
      'Quad(${corners.map((p) => '(${p.x.toStringAsFixed(1)}, ${p.y.toStringAsFixed(1)})').join(', ')})';
}

/// A detected document and how sure the detector is (0–1).
typedef QuadDetection = ({Quad quad, double score});

/// The long side frames are scaled down to before detection: enough for a
/// page's edges, cheap enough for every preview frame.
const detectionLongSide = 480;

/// Finds the document in a greyscale frame (the camera's Y plane: [width] ×
/// [height] bytes, [rowStride] bytes per row). Returns null when there is
/// no page-like quad. Coordinates are in the frame's pixels. Call it off the
/// UI isolate.
QuadDetection? detectQuadInGrey(
  Uint8List bytes,
  int width,
  int height, {
  int? rowStride,
}) {
  final stride = rowStride ?? width;
  // Drop the row padding: one buffer, a row at a time (every preview frame).
  final Uint8List packed;
  if (stride == width) {
    packed = bytes;
  } else {
    packed = Uint8List(width * height);
    for (var r = 0; r < height; r++) {
      packed.setRange(r * width, (r + 1) * width, bytes, r * stride);
    }
  }
  final grey = cv.Mat.fromList(height, width, cv.MatType.CV_8UC1, packed);
  try {
    return detectQuad(grey);
  } finally {
    grey.dispose();
  }
}

/// Finds the document in a BGR or greyscale [image] (a captured photo or an
/// imported one). See [detectQuadInGrey].
QuadDetection? detectQuad(cv.Mat image) {
  final long = math.max(image.cols, image.rows);
  final scale = long > detectionLongSide ? detectionLongSide / long : 1.0;
  final owned = <cv.Mat>[];
  cv.Mat track(cv.Mat m) {
    owned.add(m);
    return m;
  }

  try {
    var small = image;
    if (scale < 1) {
      small = track(
        cv.resize(image, (
          (image.cols * scale).round(),
          (image.rows * scale).round(),
        ), interpolation: cv.INTER_AREA),
      );
    }
    final grey = small.channels == 1
        ? small
        : track(cv.cvtColor(small, cv.COLOR_BGR2GRAY));
    final blurred = track(cv.gaussianBlur(grey, (5, 5), 0));
    // Thresholds from the frame's median, so dim and bright scenes both work.
    final median = _median(blurred);
    final edges = track(
      cv.canny(
        blurred,
        math.max(10, 0.66 * median),
        math.min(255, 1.33 * median + 30),
      ),
    );
    final kernel = track(cv.getStructuringElement(cv.MORPH_RECT, (5, 5)));
    final closed = track(cv.morphologyEx(edges, cv.MORPH_CLOSE, kernel));
    final frameArea = (small.cols * small.rows).toDouble();
    var best = _bestQuad(closed, frameArea);
    // A white page on a light desk is too faint for edges whose thresholds
    // follow the frame's brightness (DK-0662's suite): the page is the
    // brightest region there, so a threshold between it and the desk
    // (Otsu) outlines it. Tried only when the edges found nothing sure.
    if (best == null || best.score < _sure) {
      // The text closed over first (thin dark strokes on white), or the
      // threshold splits text from everything else, not page from desk.
      final big = track(cv.getStructuringElement(cv.MORPH_RECT, (9, 9)));
      final paper = track(cv.morphologyEx(blurred, cv.MORPH_CLOSE, big));
      // Halfway between the desk and the paper: the page is the brightest
      // large region, so the 95th percentile is paper.
      final cut = (_percentile(paper, 0.4) + _percentile(paper, 0.95)) / 2;
      final (_, bright) = cv.threshold(paper, cut, 255, cv.THRESH_BINARY);
      track(bright);
      final opened = track(cv.morphologyEx(bright, cv.MORPH_OPEN, kernel));
      final other = _bestQuad(opened, frameArea);
      // Only a page: not the whole frame (a pattern's light half joined
      // up), and clearly brighter than around it.
      if (other != null &&
          other.quad.area < 0.92 * frameArea &&
          _brighter(paper, other.quad) &&
          (best == null || other.score > best.score)) {
        best = other;
      }
    }
    if (best == null) return null;
    return (quad: best.quad.scaled(1 / scale), score: best.score);
  } finally {
    for (final m in owned) {
      m.dispose();
    }
  }
}

/// The smallest share of the frame a page may cover and still be found.
const minAreaShare = 0.05;

/// A candidate scoring this well needs no second look.
const _sure = 0.6;

/// Whether [quad]'s inside is clearly brighter than the rest of [grey].
bool _brighter(cv.Mat grey, Quad quad) {
  final mask = cv.Mat.zeros(grey.rows, grey.cols, cv.MatType.CV_8UC1);
  final poly = cv.VecVecPoint.fromList([
    [for (final p in quad.corners) cv.Point(p.x.round(), p.y.round())],
  ]);
  cv.fillPoly(mask, poly, cv.Scalar.all(255));
  final outside = cv.bitwiseNOT(mask);
  try {
    final inner = cv.mean(grey, mask: mask).val1;
    final outer = cv.mean(grey, mask: outside).val1;
    return inner - outer >= 15;
  } finally {
    poly.dispose();
    mask.dispose();
    outside.dispose();
  }
}

/// The best page-like quad among [binary]'s contours, or null.
QuadDetection? _bestQuad(cv.Mat binary, double frameArea) {
  final (contours, hierarchy) = cv.findContours(
    binary,
    cv.RETR_LIST,
    cv.CHAIN_APPROX_SIMPLE,
  );
  QuadDetection? best;
  try {
    for (final contour in contours) {
      // Small pages too: the hint asks to move closer (DK-0344).
      final area = cv.contourArea(contour);
      if (area < minAreaShare * frameArea) continue;
      final corners = _fourCorners(contour);
      if (corners == null) continue;
      final quad = Quad.ordered(corners);
      final score = _score(quad, frameArea);
      if (best == null || score > best.score) {
        best = (quad: quad, score: score);
      }
    }
  } finally {
    contours.dispose();
    hierarchy.dispose();
  }
  return best;
}

/// Four corners for [contour]: its polygon at growing tolerance, then its
/// convex hull's (a shadow or a finger touching the page edge adds spurs
/// that a single simplification keeps). Null when neither is a convex quad.
List<Pt>? _fourCorners(cv.VecPoint contour) {
  List<Pt>? simplify(cv.VecPoint points) {
    final peri = cv.arcLength(points, true);
    for (final f in const [0.02, 0.03, 0.045, 0.06]) {
      final approx = cv.approxPolyDP(points, f * peri, true);
      try {
        if (approx.length < 4) return null;
        if (approx.length == 4 && cv.isContourConvex(approx)) {
          return [
            for (final p in approx) (x: p.x.toDouble(), y: p.y.toDouble()),
          ];
        }
      } finally {
        approx.dispose();
      }
    }
    return null;
  }

  final direct = simplify(contour);
  if (direct != null) return direct;
  // The hull as its own points (a VecPoint made from the Mat would share
  // its memory and be freed twice).
  final hullMat = cv.convexHull(contour);
  final hull = cv.VecPoint.fromList([
    for (var i = 0; i < hullMat.rows; i++)
      cv.Point(
        hullMat.at<cv.Vec2i>(i, 0).val1,
        hullMat.at<cv.Vec2i>(i, 0).val2,
      ),
  ]);
  hullMat.dispose();
  try {
    return simplify(hull);
  } finally {
    hull.dispose();
  }
}

/// Scores a candidate: its share of the frame and how close its corners are
/// to right angles (a page seen in perspective stays near 90° ± 30°).
double _score(Quad q, double frameArea) {
  final areaShare = (q.area / frameArea).clamp(0.0, 1.0);
  final c = q.corners;
  var worst = 0.0;
  for (var i = 0; i < 4; i++) {
    final p = c[i], a = c[(i + 3) % 4], b = c[(i + 1) % 4];
    final v1 = (x: a.x - p.x, y: a.y - p.y), v2 = (x: b.x - p.x, y: b.y - p.y);
    final cos =
        (v1.x * v2.x + v1.y * v2.y) /
        (math.sqrt(v1.x * v1.x + v1.y * v1.y) *
            math.sqrt(v2.x * v2.x + v2.y * v2.y));
    worst = math.max(worst, cos.abs());
  }
  // cos 0 = a right angle; cos 0.5 = 60° or 120°.
  final angles = (1 - worst / 0.5).clamp(0.0, 1.0);
  return 0.5 * areaShare.clamp(0.0, 0.9) / 0.9 + 0.5 * angles;
}

double _median(cv.Mat grey) => _percentile(grey, 0.5);

/// The grey level below which [q] of [grey]'s pixels lie.
double _percentile(cv.Mat grey, double q) {
  // ponytail: a 256-bin histogram by hand on a 480 px frame; cv.calcHist if it shows in a profile.
  final data = grey.data;
  final hist = List.filled(256, 0);
  for (final v in data) {
    hist[v]++;
  }
  var seen = 0;
  for (var i = 0; i < 256; i++) {
    seen += hist[i];
    if (seen >= q * data.length) return i.toDouble();
  }
  return 127;
}

/// Warps the page inside [quad] flat (perspective fix on capture). The
/// output keeps the quad's longest edges as its width and height. Returns a
/// new Mat the caller disposes.
cv.Mat warpQuad(cv.Mat image, Quad quad) {
  double dist(Pt a, Pt b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
  final w = math
      .max(
        dist(quad.topLeft, quad.topRight),
        dist(quad.bottomLeft, quad.bottomRight),
      )
      .round();
  final h = math
      .max(
        dist(quad.topLeft, quad.bottomLeft),
        dist(quad.topRight, quad.bottomRight),
      )
      .round();
  final src = cv.VecPoint2f.fromList([
    for (final p in quad.corners) cv.Point2f(p.x, p.y),
  ]);
  final dst = cv.VecPoint2f.fromList([
    cv.Point2f(0, 0),
    cv.Point2f(w - 1, 0),
    cv.Point2f(w - 1, h - 1),
    cv.Point2f(0, h - 1),
  ]);
  final m = cv.getPerspectiveTransform2f(src, dst);
  final out = cv.warpPerspective(image, m, (w, h));
  src.dispose();
  dst.dispose();
  m.dispose();
  return out;
}

/// Follows the detected quad across preview frames and says when it has
/// held still long enough to capture (DK-0338: ~0.5 s steady).
class QuadTracker {
  QuadTracker({
    this.steadyFor = const Duration(milliseconds: 500),
    this.tolerance = 0.02,
  });

  /// How long the quad must hold still.
  final Duration steadyFor;

  /// How far a corner may move between frames and still count as still, as
  /// a share of the quad's diagonal.
  final double tolerance;

  Quad? _last;
  Duration? _since;

  /// The quad shown to the user (the latest one), or null when lost.
  Quad? get quad => _last;

  /// Feeds the detection for the frame taken at [time] (null when the frame
  /// has no document) and returns how far the countdown is, 0–1; 1 = capture.
  double update(Quad? quad, Duration time) {
    if (quad == null) {
      _last = null;
      _since = null;
      return 0;
    }
    final last = _last;
    final diagonal = math.sqrt(
      math.pow(quad.topLeft.x - quad.bottomRight.x, 2) +
          math.pow(quad.topLeft.y - quad.bottomRight.y, 2),
    );
    if (last == null || quad.maxCornerShift(last) > tolerance * diagonal) {
      _since = time;
    }
    _last = quad;
    return progress(time);
  }

  /// The countdown at [time], 0–1, for the shutter's arc.
  double progress(Duration time) {
    final since = _since;
    if (since == null) return 0;
    return ((time - since).inMicroseconds / steadyFor.inMicroseconds).clamp(
      0.0,
      1.0,
    );
  }

  /// Starts over (after a capture, or when the user moves on).
  void reset() {
    _last = null;
    _since = null;
  }
}
