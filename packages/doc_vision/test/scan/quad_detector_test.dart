import 'dart:math' as math;

import 'package:doc_vision/doc_vision.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

/// A desk photo: a textured dark background with a white page, drawn as the
/// quad [corners] (clockwise from top-left), with a few text lines on it.
cv.Mat scene(
  List<(int, int)> corners, {
  int w = 960,
  int h = 1280,
  int seed = 1,
}) {
  final img = cv.Mat.create(
    rows: h,
    cols: w,
    r: 70,
    g: 60,
    b: 50,
    type: cv.MatType.CV_8UC3,
  );
  final rnd = math.Random(seed);
  // Wood-like streaks, so Canny sees clutter as well as the page.
  for (var i = 0; i < 40; i++) {
    final y = rnd.nextInt(h);
    final c = 40 + rnd.nextInt(60);
    cv.line(
      img,
      cv.Point(0, y),
      cv.Point(w, y + rnd.nextInt(40) - 20),
      cv.Scalar(c.toDouble(), (c + 10).toDouble(), (c + 20).toDouble()),
      thickness: 2,
    );
  }
  final pts = cv.VecVecPoint.fromList([
    [for (final (x, y) in corners) cv.Point(x, y)],
  ]);
  cv.fillPoly(img, pts, cv.Scalar(245, 245, 240));
  // Text lines inside the page (between its top and bottom edges).
  final (tlx, tly) = corners[0];
  final (brx, bry) = corners[2];
  for (var y = tly + 80; y < bry - 80; y += 40) {
    cv.line(
      img,
      cv.Point(tlx + 70, y),
      cv.Point(brx - 120, y),
      cv.Scalar(30, 30, 30),
      thickness: 6,
    );
  }
  pts.dispose();
  return img;
}

void expectNear(Quad q, List<(int, int)> want, double tol) {
  for (var i = 0; i < 4; i++) {
    final got = q.corners[i];
    final (x, y) = want[i];
    expect(
      math.sqrt(math.pow(got.x - x, 2) + math.pow(got.y - y, 2)),
      lessThan(tol),
      reason: 'corner $i: $q vs $want',
    );
  }
}

void main() {
  test('Quad.ordered sorts any order clockwise from top-left', () {
    final q = Quad.ordered([
      (x: 90, y: 110),
      (x: 10, y: 10),
      (x: 100, y: 5),
      (x: 0, y: 100),
    ]);
    expect(q.topLeft, (x: 10.0, y: 10.0));
    expect(q.topRight, (x: 100.0, y: 5.0));
    expect(q.bottomRight, (x: 90.0, y: 110.0));
    expect(q.bottomLeft, (x: 0.0, y: 100.0));
    expect(q.area, closeTo(9025, 600));
  });

  // A small synthetic corpus: straight, tilted, in perspective, small, large.
  const pages = {
    'straight': [(180, 160), (780, 160), (780, 1120), (180, 1120)],
    'tilted': [(250, 120), (830, 230), (700, 1150), (120, 1030)],
    'perspective': [(300, 200), (680, 210), (860, 1150), (110, 1130)],
    'small': [(330, 420), (640, 430), (630, 860), (320, 850)],
    'large': [(40, 40), (920, 50), (910, 1240), (50, 1230)],
  };
  for (final MapEntry(key: name, value: corners) in pages.entries) {
    test('finds the page: $name', () {
      final img = scene(corners, seed: name.length);
      final found = detectQuad(img);
      img.dispose();
      expect(found, isNotNull);
      expectNear(found!.quad, corners, 20);
      expect(found.score, greaterThan(0.5));
    });
  }

  test('a Y-plane frame with row padding gives the same quad', () {
    final corners = pages['perspective']!;
    final img = scene(corners);
    final grey = cv.cvtColor(img, cv.COLOR_BGR2GRAY);
    const pad = 64;
    final stride = grey.cols + pad;
    final data = grey.data;
    final padded = List<int>.filled(stride * grey.rows, 0);
    for (var r = 0; r < grey.rows; r++) {
      padded.setRange(r * stride, r * stride + grey.cols, data, r * grey.cols);
    }
    final found = detectQuadInGrey(
      cv.Mat.fromList(1, padded.length, cv.MatType.CV_8UC1, padded).data,
      grey.cols,
      grey.rows,
      rowStride: stride,
    );
    expect(found, isNotNull);
    expectNear(found!.quad, corners, 20);
    img.dispose();
    grey.dispose();
  });

  test('no document: null', () {
    final img = cv.Mat.create(
      rows: 800,
      cols: 600,
      r: 70,
      g: 60,
      b: 50,
      type: cv.MatType.CV_8UC3,
    );
    cv.line(
      img,
      cv.Point(0, 300),
      cv.Point(600, 320),
      cv.Scalar(200, 200, 200),
      thickness: 3,
    );
    expect(detectQuad(img), isNull);
    img.dispose();
  });

  test('warpQuad flattens the page to its longest edges', () {
    final corners = pages['perspective']!;
    final img = scene(corners);
    final q = detectQuad(img)!.quad;
    final flat = warpQuad(img, q);
    // Mostly paper: the page fills the output.
    final grey = cv.cvtColor(flat, cv.COLOR_BGR2GRAY);
    expect(cv.mean(grey).val1, greaterThan(180));
    expect(flat.cols, inInclusiveRange(700, 800));
    expect(flat.rows, inInclusiveRange(900, 980));
    for (final m in [img, flat, grey]) {
      m.dispose();
    }
  });

  group('QuadTracker', () {
    const q = Quad(
      (x: 100, y: 100),
      (x: 500, y: 100),
      (x: 500, y: 700),
      (x: 100, y: 700),
    );
    Quad moved(double d) => Quad(
      (x: 100 + d, y: 100),
      (x: 500 + d, y: 100),
      (x: 500 + d, y: 700),
      (x: 100 + d, y: 700),
    );
    Duration ms(int v) => Duration(milliseconds: v);

    test('steady for 0.5 s reaches 1; the arc follows the time', () {
      final t = QuadTracker();
      expect(t.update(q, ms(0)), 0);
      expect(t.update(moved(2), ms(250)), closeTo(0.5, 0.01));
      expect(t.update(moved(4), ms(500)), 1);
    });

    test('a jump restarts the countdown; losing the page resets it', () {
      final t = QuadTracker();
      t.update(q, ms(0));
      t.update(q, ms(400));
      expect(t.update(moved(80), ms(450)), 0);
      expect(t.update(moved(80), ms(700)), closeTo(0.5, 0.01));
      expect(t.update(null, ms(750)), 0);
      expect(t.quad, isNull);
      expect(t.update(q, ms(800)), 0);
    });
  });
}
