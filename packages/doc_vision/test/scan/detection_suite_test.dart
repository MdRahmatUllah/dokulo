import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:doc_vision/doc_vision.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

/// The scanner's detection suite (DK-0662; Technology & Package Plan →
/// Testing → Test suites): quad detection on a photo set across
/// backgrounds, lighting and angles. The photos are synthetic (drawn here):
/// the repository is public and holds no one's documents. Each case checks
/// the four corners against the page that was drawn.
///
/// The blocking cases must all pass (a failure blocks the release); the
/// others are recorded and must pass at [recordedFloor] overall. The run
/// writes its table to `build/detection_suite.md`; the release procedure
/// copies it into docs/qa/scanner-detection.md.

/// Where the page is, clockwise from top-left, on a 960 × 1280 photo.
const placements = {
  'straight': [(180, 160), (780, 160), (780, 1120), (180, 1120)],
  'tilted': [(250, 120), (830, 230), (700, 1150), (120, 1030)],
  'perspective': [(300, 200), (680, 210), (860, 1150), (110, 1130)],
  'small': [(330, 420), (640, 430), (630, 860), (320, 850)],
  'large': [(40, 40), (920, 50), (910, 1240), (50, 1230)],
};

enum Background { darkWood, blueCloth, checker, lightDesk }

enum Lighting { even, dim, bright, gradient, shadow, glare, blur }

/// The cases that block a release: ordinary desks (dark wood, a coloured
/// cloth) in ordinary light. A light desk and a patterned cloth are harder
/// and recorded.
bool blocking(Background b, Lighting l, String placement) =>
    {Background.darkWood, Background.blueCloth}.contains(b) &&
    {Lighting.even, Lighting.dim, Lighting.bright}.contains(l) &&
    {'straight', 'tilted', 'perspective'}.contains(placement);

/// The share of all the other cases that must pass.
const recordedFloor = 0.8;

/// A corner may be this far off (px of the 960 × 1280 photo, ~1.6 % of its
/// diagonal): the crop UI shows it, the user nudges it.
const tolerance = 25.0;

const _w = 960, _h = 1280;

cv.Mat photo(List<(int, int)> corners, Background bg, Lighting light) {
  final (b, g, r) = switch (bg) {
    Background.darkWood => (50, 60, 70),
    Background.blueCloth => (120, 70, 30),
    Background.checker => (90, 90, 90),
    Background.lightDesk => (196, 198, 200),
  };
  final img = cv.Mat.create(
    rows: _h,
    cols: _w,
    r: r,
    g: g,
    b: b,
    type: cv.MatType.CV_8UC3,
  );
  final rnd = math.Random(bg.index * 31 + light.index);
  switch (bg) {
    case Background.darkWood || Background.lightDesk:
      final base = bg == Background.darkWood ? 40 : 180;
      for (var i = 0; i < 40; i++) {
        final y = rnd.nextInt(_h);
        final c = (base + rnd.nextInt(bg == Background.darkWood ? 60 : 20))
            .toDouble();
        cv.line(
          img,
          cv.Point(0, y),
          cv.Point(_w, y + rnd.nextInt(40) - 20),
          cv.Scalar(c, c + 5, c + 10),
          thickness: 2,
        );
      }
    case Background.blueCloth:
      for (var x = 0; x < _w; x += 12) {
        cv.line(img, cv.Point(x, 0), cv.Point(x, _h), cv.Scalar(100, 55, 20));
      }
    case Background.checker:
      for (var y = 0; y < _h; y += 40) {
        for (var x = (y ~/ 40).isEven ? 0 : 40; x < _w; x += 80) {
          cv.rectangle(
            img,
            cv.Rect(x, y, 40, 40),
            cv.Scalar(150, 150, 150),
            thickness: -1,
          );
        }
      }
  }
  final page = cv.VecVecPoint.fromList([
    [for (final (x, y) in corners) cv.Point(x, y)],
  ]);
  cv.fillPoly(img, page, cv.Scalar(245, 245, 240));
  page.dispose();
  // Text lines, inside the page only.
  final cx = corners.map((c) => c.$1).reduce((a, b) => a + b) / 4;
  final cy = corners.map((c) => c.$2).reduce((a, b) => a + b) / 4;
  final inner = cv.VecVecPoint.fromList([
    [
      for (final (x, y) in corners)
        cv.Point((x + (cx - x) * 0.18).round(), (y + (cy - y) * 0.18).round()),
    ],
  ]);
  final mask = cv.Mat.zeros(_h, _w, cv.MatType.CV_8UC1);
  cv.fillPoly(mask, inner, cv.Scalar.all(255));
  inner.dispose();
  final text = cv.Mat.create(
    rows: _h,
    cols: _w,
    r: 240,
    g: 245,
    b: 245,
    type: cv.MatType.CV_8UC3,
  );
  for (var y = 0; y < _h; y += 36) {
    cv.line(
      text,
      cv.Point(0, y),
      cv.Point(_w, y),
      cv.Scalar(30, 30, 30),
      thickness: 5,
    );
  }
  text.copyTo(img, mask: mask);
  text.dispose();
  mask.dispose();
  return _light(img, light, corners, rnd);
}

cv.Mat _light(
  cv.Mat img,
  Lighting light,
  List<(int, int)> corners,
  math.Random rnd,
) {
  cv.Mat replace(cv.Mat next) {
    img.dispose();
    return next;
  }

  switch (light) {
    case Lighting.even:
      return img;
    case Lighting.dim:
      return replace(cv.convertScaleAbs(img, alpha: 0.4));
    case Lighting.bright:
      return replace(cv.convertScaleAbs(img, alpha: 1.15, beta: 25));
    case Lighting.gradient:
      // Light falls off from the right: half as bright at the left edge.
      final ramp = Uint8List(_w * _h * 3);
      for (var y = 0; y < _h; y++) {
        for (var x = 0; x < _w; x++) {
          final v = (128 + 127 * x / _w).round();
          final i = (y * _w + x) * 3;
          ramp[i] = ramp[i + 1] = ramp[i + 2] = v;
        }
      }
      final mat = cv.Mat.fromList(_h, _w, cv.MatType.CV_8UC3, ramp);
      final out = cv.multiply(img, mat, scale: 1 / 255);
      mat.dispose();
      return replace(out);
    case Lighting.shadow:
      // A hand's shadow over the lower left of the page.
      final dark = cv.convertScaleAbs(img, alpha: 0.5);
      final (blx, bly) = corners[3];
      final (cx, cy) = (
        corners.map((c) => c.$1).reduce((a, b) => a + b) ~/ 4,
        corners.map((c) => c.$2).reduce((a, b) => a + b) ~/ 4,
      );
      final mask = cv.Mat.zeros(_h, _w, cv.MatType.CV_8UC1);
      final poly = cv.VecVecPoint.fromList([
        [
          cv.Point(0, cy),
          cv.Point(cx, cy + 40),
          cv.Point(blx + 120, _h),
          cv.Point(0, _h),
        ],
      ]);
      cv.fillPoly(mask, poly, cv.Scalar.all(255));
      dark.copyTo(img, mask: mask);
      for (final m in [dark, mask]) {
        m.dispose();
      }
      poly.dispose();
      return img;
    case Lighting.glare:
      // A lamp's reflection near the top-right corner, softened.
      final (x, y) = corners[1];
      cv.circle(
        img,
        cv.Point(x - 90, y + 110),
        80,
        cv.Scalar.all(255),
        thickness: -1,
      );
      return replace(cv.gaussianBlur(img, (7, 7), 0));
    case Lighting.blur:
      // A shaky hand.
      return replace(cv.gaussianBlur(img, (13, 13), 0));
  }
}

/// The largest corner error, or null when nothing was found.
double? error(QuadDetection? found, List<(int, int)> want) {
  if (found == null) return null;
  var worst = 0.0;
  for (var i = 0; i < 4; i++) {
    final got = found.quad.corners[i];
    final (x, y) = want[i];
    worst = math.max(
      worst,
      math.sqrt(math.pow(got.x - x, 2) + math.pow(got.y - y, 2)),
    );
  }
  return worst;
}

void main() {
  final rows = <String>[];
  var recorded = 0, recordedPassed = 0;

  for (final bg in Background.values) {
    for (final light in Lighting.values) {
      for (final MapEntry(key: placement, value: corners)
          in placements.entries) {
        final name = '${bg.name} · ${light.name} · $placement';
        final blocks = blocking(bg, light, placement);
        test('${blocks ? 'blocking' : 'recorded'}: $name', () {
          final img = photo(corners, bg, light);
          final found = detectQuad(img);
          img.dispose();
          final e = error(found, corners);
          final ok = e != null && e < tolerance;
          rows.add(
            '| $name | ${blocks ? 'yes' : ''} | '
            '${e == null ? 'not found' : '${e.toStringAsFixed(1)} px'} | '
            '${ok ? 'pass' : 'FAIL'} |',
          );
          if (blocks) {
            expect(ok, isTrue, reason: '$name: corner error $e');
          } else {
            recorded++;
            if (ok) recordedPassed++;
          }
        });
      }
    }
  }

  for (final bg in Background.values) {
    test('no page on ${bg.name}: nothing found', () {
      final img = photo(const [(0, 0), (0, 0), (0, 0), (0, 0)], bg, .even);
      expect(detectQuad(img), isNull);
      img.dispose();
    });
  }

  tearDownAll(() {
    final rate = recorded == 0 ? 1.0 : recordedPassed / recorded;
    final report = [
      '# Scanner detection suite (DK-0662)',
      '',
      'Recorded cases: $recordedPassed of $recorded pass '
          '(${(rate * 100).toStringAsFixed(0)} %, floor '
          '${(recordedFloor * 100).round()} %).',
      '',
      '| Case | Blocking | Worst corner | Result |',
      '| --- | --- | --- | --- |',
      ...rows..sort(),
    ].join('\n');
    Directory('build').createSync(recursive: true);
    File('build/detection_suite.md').writeAsStringSync('$report\n');
    expect(
      rate,
      greaterThanOrEqualTo(recordedFloor),
      reason: 'recorded cases: $recordedPassed of $recorded',
    );
  });
}
