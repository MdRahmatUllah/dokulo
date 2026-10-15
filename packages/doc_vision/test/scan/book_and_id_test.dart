import 'package:doc_vision/doc_vision.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

/// A page of text: white with dark lines, rotated by [skew] degrees.
cv.Mat textPage(int w, int h, {double skew = 0}) {
  final page = cv.Mat.create(
    rows: h,
    cols: w,
    r: 250,
    g: 250,
    b: 245,
    type: cv.MatType.CV_8UC3,
  );
  for (var y = 40; y < h - 40; y += 28) {
    cv.line(
      page,
      cv.Point(30, y),
      cv.Point(w - 30, y),
      cv.Scalar(30, 30, 30),
      thickness: 6,
    );
  }
  if (skew == 0) return page;
  final out = rotated(page, skew);
  page.dispose();
  return out;
}

void main() {
  test('textSkew finds the angle of the lines', () {
    for (final skew in [-4.0, 0.0, 3.0]) {
      final page = textPage(500, 640, skew: skew);
      expect(textSkew(page), closeTo(skew, 0.6), reason: '$skew°');
      page.dispose();
    }
  });

  test('a spread: the spine is found in the gutter and each page comes out straight', () {
    const w = 1200, h = 800, gutter = 630;
    final left = textPage(gutter, h, skew: 3);
    final right = textPage(w - gutter, h, skew: -2);
    final spread = cv.Mat.create(
      rows: h,
      cols: w,
      r: 250,
      g: 250,
      b: 245,
      type: cv.MatType.CV_8UC3,
    );
    left.copyTo(spread.region(cv.Rect(0, 0, gutter, h)));
    right.copyTo(spread.region(cv.Rect(gutter, 0, w - gutter, h)));
    // The gutter's shadow and its crease.
    cv.rectangle(
      spread,
      cv.Rect(gutter - 10, 0, 20, h),
      cv.Scalar(120, 120, 120),
      thickness: -1,
    );
    cv.line(
      spread,
      cv.Point(gutter, 0),
      cv.Point(gutter, h),
      cv.Scalar(40, 40, 40),
      thickness: 2,
    );

    expect(findSpine(spread), closeTo(gutter, w * 0.02));
    final split = splitSpread(spread);
    expect(split.spine, closeTo(gutter, w * 0.02));
    expect(textSkew(split.left), closeTo(0, 0.6));
    expect(textSkew(split.right), closeTo(0, 0.6));
    for (final m in [left, right, spread, split.left, split.right]) {
      m.dispose();
    }
  });

  test('cropIdCard: ID-1 at 300 dpi, landscape even when held upright', () {
    final photo = cv.Mat.create(
      rows: 900,
      cols: 700,
      r: 60,
      g: 60,
      b: 60,
      type: cv.MatType.CV_8UC3,
    );
    // An upright card (taller than wide) in the photo.
    const quad = Quad(
      (x: 200, y: 150),
      (x: 500, y: 150),
      (x: 500, y: 625),
      (x: 200, y: 625),
    );
    final pts = cv.VecVecPoint.fromList([
      [for (final p in quad.corners) cv.Point(p.x.round(), p.y.round())],
    ]);
    cv.fillPoly(photo, pts, cv.Scalar(230, 220, 200));
    final card = cropIdCard(photo, quad);
    expect((card.cols, card.rows), idCardPixels);
    expect(card.cols / card.rows, closeTo(idCardAspect, 0.01));
    expect(
      cv.mean(card).val1,
      greaterThan(180),
      reason: 'the card fills the crop',
    );
    for (final m in [photo, card]) {
      m.dispose();
    }
    pts.dispose();
  });
}
