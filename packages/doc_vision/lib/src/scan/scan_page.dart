import 'dart:math' as math;
import 'dart:typed_data';

import 'package:opencv_dart/opencv_dart.dart' as cv;

import 'quad_detector.dart';
import 'scan_filters.dart';

/// How one scanned page is turned into its saved image (DK-0359).
typedef ScanPageJob = ({
  /// The photo as captured or imported (JPEG, PNG, WebP).
  Uint8List photo,

  /// The page's corners as fractions of the photo (0–1), clockwise from
  /// top-left; null: the whole photo.
  List<Pt>? corners,

  /// Quarter turns clockwise.
  int turns,
  ScanFilter filter,

  /// The S2 sliders, -0.5 to 0.5.
  double brightness,
  double contrast,

  /// The long side at most, in pixels (null: as warped).
  int? longSide,

  /// JPEG quality, 0–100.
  int jpegQuality,
});

/// The saved page: the photo warped flat to its corners, turned, filtered,
/// scaled down to [ScanPageJob.longSide] and encoded as JPEG. Runs OpenCV:
/// call it on a worker isolate.
({Uint8List jpeg, int width, int height}) renderScanPage(ScanPageJob job) {
  final owned = <cv.Mat>[];
  cv.Mat track(cv.Mat m) {
    owned.add(m);
    return m;
  }

  try {
    var page = track(cv.imdecode(job.photo, cv.IMREAD_COLOR));
    if (page.isEmpty) throw const FormatException('not an image');
    if (job.corners case final c? when c.length == 4) {
      final w = page.cols.toDouble(), h = page.rows.toDouble();
      Pt px(Pt p) => (x: p.x * w, y: p.y * h);
      page = track(
        warpQuad(page, Quad(px(c[0]), px(c[1]), px(c[2]), px(c[3]))),
      );
    }
    final turns = job.turns % 4;
    if (turns != 0) {
      page = track(
        cv.rotate(page, switch (turns) {
          1 => cv.ROTATE_90_CLOCKWISE,
          2 => cv.ROTATE_180,
          _ => cv.ROTATE_90_COUNTERCLOCKWISE,
        }),
      );
    }
    page = track(
      applyScanFilter(
        page,
        job.filter,
        // The sliders' -0.5…0.5 is applyScanFilter's -1…1 halved.
        brightness: job.brightness,
        contrast: job.contrast,
      ),
    );
    if (job.longSide case final side?) {
      final long = math.max(page.cols, page.rows);
      if (long > side) {
        final s = side / long;
        page = track(
          cv.resize(page, (
            (page.cols * s).round(),
            (page.rows * s).round(),
          ), interpolation: cv.INTER_AREA),
        );
      }
    }
    final params = cv.VecI32.fromList([
      cv.IMWRITE_JPEG_QUALITY,
      job.jpegQuality,
    ]);
    final (ok, jpeg) = cv.imencode('.jpg', page, params: params);
    params.dispose();
    if (!ok) throw StateError('JPEG encoding failed');
    return (jpeg: jpeg, width: page.cols, height: page.rows);
  } finally {
    for (final m in owned) {
      m.dispose();
    }
  }
}
