import 'dart:typed_data';

import 'package:opencv_dart/opencv_dart.dart' as cv;

/// A changed area of a page, as fractions of the page (0–1), origin
/// top-left.
typedef DiffRegion = ({double left, double top, double right, double bottom});

/// Compare's visual mode (DK-0529; UI spec §21.24): the two renderings of a
/// page (encoded images, e.g. PNG from the page renderer) brought to the
/// same size, their absolute difference thresholded, nearby differences
/// grouped by a dilation into regions. Regions under [minShare] of the page
/// (scan noise) are dropped. Works on scans, where there is no text to
/// diff. OpenCV: call it on a worker isolate.
List<DiffRegion> visualDiff(
  Uint8List older,
  Uint8List newer, {
  int threshold = 40,
  double minShare = 0.0005,
}) {
  final owned = <cv.Mat>[];
  cv.Mat track(cv.Mat m) {
    owned.add(m);
    return m;
  }

  try {
    final a = track(cv.imdecode(older, cv.IMREAD_GRAYSCALE));
    var b = track(cv.imdecode(newer, cv.IMREAD_GRAYSCALE));
    if (a.isEmpty || b.isEmpty) throw const FormatException('not an image');
    if (a.cols != b.cols || a.rows != b.rows) {
      b = track(cv.resize(b, (a.cols, a.rows), interpolation: cv.INTER_AREA));
    }
    // A light blur first: a scan's grain and a sub-pixel shift aren't
    // changes.
    final diff = track(
      cv.absDiff(
        track(cv.gaussianBlur(a, (5, 5), 0)),
        track(cv.gaussianBlur(b, (5, 5), 0)),
      ),
    );
    final (_, mask) = cv.threshold(
      diff,
      threshold.toDouble(),
      255,
      cv.THRESH_BINARY,
    );
    track(mask);
    // Group a changed word's letters, and the lines of a changed paragraph.
    final side = (a.cols / 60).round().clamp(5, 40);
    final kernel = track(cv.getStructuringElement(cv.MORPH_RECT, (side, side)));
    final grouped = track(cv.dilate(mask, kernel));
    final (contours, hierarchy) = cv.findContours(
      grouped,
      cv.RETR_EXTERNAL,
      cv.CHAIN_APPROX_SIMPLE,
    );
    final w = a.cols.toDouble(), h = a.rows.toDouble();
    try {
      final regions = <DiffRegion>[];
      for (final c in contours) {
        final r = cv.boundingRect(c);
        if (r.width * r.height < minShare * w * h) continue;
        regions.add((
          left: r.x / w,
          top: r.y / h,
          right: (r.x + r.width) / w,
          bottom: (r.y + r.height) / h,
        ));
      }
      // Top to bottom, then left to right: the changes list's order.
      return regions..sort(
        (p, q) =>
            p.top != q.top ? p.top.compareTo(q.top) : p.left.compareTo(q.left),
      );
    } finally {
      contours.dispose();
      hierarchy.dispose();
    }
  } finally {
    for (final m in owned) {
      m.dispose();
    }
  }
}
