import 'dart:typed_data';

import 'package:doc_vision/doc_vision.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

/// A page: white, with text-like bars at [lines] (y in px), 800 × 1100.
Uint8List page(List<int> lines, {int noise = 0}) {
  final m = cv.Mat.create(
    rows: 1100,
    cols: 800,
    r: 255,
    g: 255,
    b: 255,
    type: cv.MatType.CV_8UC3,
  );
  for (final y in lines) {
    cv.rectangle(
      m,
      cv.Rect(80, y, 600, 14),
      cv.Scalar(30, 30, 30),
      thickness: -1,
    );
  }
  if (noise > 0) {
    // Scan grain: a few dots a blur and the area floor drop.
    for (var i = 0; i < noise; i++) {
      cv.circle(
        m,
        cv.Point(20 + i * 37 % 760, 30 + i * 53 % 1040),
        1,
        cv.Scalar(200, 200, 200),
        thickness: -1,
      );
    }
  }
  final png = cv.imencode('.png', m).$2;
  m.dispose();
  return png;
}

void main() {
  test('the same page: no regions, even with scan grain', () {
    expect(visualDiff(page([100, 140]), page([100, 140], noise: 40)), isEmpty);
  });

  test('a changed line and an added paragraph: two regions, top first', () {
    final regions = visualDiff(
      page([100, 140, 180]),
      page([100, 180, 600, 620, 640]),
    );
    expect(regions, hasLength(2));
    expect(regions.first.top, closeTo(140 / 1100, 0.03));
    expect(regions.last.top, closeTo(600 / 1100, 0.03));
    expect(regions.last.bottom, greaterThan(640 / 1100));
  });

  test('a rendering at another size is compared at the first one\'s', () {
    final big = cv.imdecode(page([100]), cv.IMREAD_COLOR);
    final scaled = cv.resize(big, (1600, 2200));
    final png = cv.imencode('.png', scaled).$2;
    big.dispose();
    scaled.dispose();
    expect(visualDiff(page([100]), png), isEmpty);
  });
}
