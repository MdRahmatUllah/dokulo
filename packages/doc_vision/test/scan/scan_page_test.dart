import 'dart:typed_data';

import 'package:doc_vision/doc_vision.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import 'quad_detector_test.dart' show scene;

void main() {
  // A 960 × 1280 desk photo; the page from (200,180) to (760,1100).
  late Uint8List photo;
  const corners = [
    (x: 200 / 960, y: 180 / 1280),
    (x: 760 / 960, y: 180 / 1280),
    (x: 760 / 960, y: 1100 / 1280),
    (x: 200 / 960, y: 1100 / 1280),
  ];

  setUpAll(() {
    final img = scene([(200, 180), (760, 180), (760, 1100), (200, 1100)]);
    photo = cv.imencode('.jpg', img).$2;
    img.dispose();
  });

  ScanPageJob job({
    List<Pt>? crop = corners,
    int turns = 0,
    ScanFilter filter = ScanFilter.original,
    int? longSide,
    int quality = 82,
  }) => (
    photo: photo,
    corners: crop,
    turns: turns,
    filter: filter,
    brightness: 0,
    contrast: 0,
    longSide: longSide,
    jpegQuality: quality,
  );

  test('cut to the corners: the page alone, flat', () {
    final page = renderScanPage(job());
    expect(page.width, closeTo(560, 2));
    expect(page.height, closeTo(920, 2));
    final m = cv.imdecode(page.jpeg, cv.IMREAD_GRAYSCALE);
    // Paper all round: the desk is gone.
    expect(m.at<int>(4, 4), greaterThan(200));
    expect(m.at<int>(m.rows - 5, m.cols - 5), greaterThan(200));
    m.dispose();
  });

  test('no corners: the whole photo', () {
    final page = renderScanPage(job(crop: null));
    expect((page.width, page.height), (960, 1280));
  });

  test('a quarter turn swaps the sides', () {
    final page = renderScanPage(job(turns: 1));
    expect(page.width, closeTo(920, 2));
    expect(page.height, closeTo(560, 2));
  });

  test('the long side is capped; lower quality is smaller', () {
    final small = renderScanPage(job(longSide: 400, quality: 60));
    expect(small.height, 400);
    final best = renderScanPage(job(quality: 95));
    expect(small.jpeg.length, lessThan(best.jpeg.length));
  });

  test('a filter applies (black and white: one channel)', () {
    final page = renderScanPage(job(filter: ScanFilter.blackWhite));
    final m = cv.imdecode(page.jpeg, cv.IMREAD_UNCHANGED);
    expect(m.channels, 1);
    m.dispose();
  });

  test('not an image: FormatException', () {
    expect(
      () => renderScanPage((
        photo: Uint8List.fromList([1, 2, 3]),
        corners: null,
        turns: 0,
        filter: ScanFilter.original,
        brightness: 0,
        contrast: 0,
        longSide: null,
        jpegQuality: 80,
      )),
      throwsFormatException,
    );
  });
}
