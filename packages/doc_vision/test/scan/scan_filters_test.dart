import 'dart:io';
import 'dart:typed_data';

import 'package:doc_vision/doc_vision.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

/// Golden images for each scanner filter (DK-0339). Regenerate with
/// `UPDATE_GOLDENS=1 flutter test test/scan/scan_filters_test.dart`.
void main() {
  final update = Platform.environment['UPDATE_GOLDENS'] == '1';
  final letter = File('test/fixtures/ocr/letter-de.jpg').readAsBytesSync();

  // A page with a shadow across it: the letter, darkened towards the right.
  late Uint8List shadowed;
  setUpAll(() {
    final page = cv.imdecode(letter, cv.IMREAD_COLOR);
    final small = cv.resize(page, (
      320,
      (320 * page.rows / page.cols).round(),
    ), interpolation: cv.INTER_AREA);
    final shade = cv.Mat.zeros(small.rows, small.cols, cv.MatType.CV_8UC3);
    for (var x = 0; x < small.cols; x++) {
      final v = (110 * x / small.cols).round();
      cv.rectangle(
        shade,
        cv.Rect(x, 0, 1, small.rows),
        cv.Scalar(v.toDouble(), v.toDouble(), v.toDouble()),
        thickness: -1,
      );
    }
    final dark = cv.subtract(small, shade);
    shadowed = cv.imencode('.png', dark).$2;
    for (final m in [page, small, shade, dark]) {
      m.dispose();
    }
  });

  for (final filter in ScanFilter.values) {
    test('golden: ${filter.name}', () {
      final png = filterImageSync(shadowed, filter, ext: '.png');
      final golden = File('test/scan/goldens/${filter.name}.png');
      if (update || !golden.existsSync()) {
        golden.createSync(recursive: true);
        golden.writeAsBytesSync(png);
        if (!update) {
          fail('no golden yet: wrote ${golden.path}; check it and run again');
        }
      }
      expect(_meanDiff(png, golden.readAsBytesSync()), lessThan(1.0));
    });
  }

  test(
    'greyscale and black-and-white are one channel; B/W is only 0 and 255',
    () {
      for (final f in [ScanFilter.greyscale, ScanFilter.blackWhite]) {
        final m = cv.imdecode(
          filterImageSync(shadowed, f, ext: '.png'),
          cv.IMREAD_UNCHANGED,
        );
        expect(m.channels, 1, reason: f.name);
        if (f == ScanFilter.blackWhite) {
          final nonBinary = cv.countNonZero(
            cv.inRange(
              m,
              cv.Mat.fromScalar(1, 1, cv.MatType.CV_8UC1, cv.Scalar.all(1)),
              cv.Mat.fromScalar(1, 1, cv.MatType.CV_8UC1, cv.Scalar.all(254)),
            ),
          );
          expect(nonBinary, 0);
        }
        m.dispose();
      }
    },
  );

  test('shadow removal brightens the shaded side of the paper', () {
    double rightPaper(Uint8List png) {
      final m = cv.imdecode(png, cv.IMREAD_GRAYSCALE);
      // The right margin, where there is paper and no text.
      final roi = m.region(cv.Rect(m.cols - 12, 0, 8, m.rows));
      final mean = cv.mean(roi).val1;
      m.dispose();
      return mean;
    }

    final before = rightPaper(shadowed);
    final after = rightPaper(
      filterImageSync(shadowed, ScanFilter.removeShadows, ext: '.png'),
    );
    expect(after, greaterThan(before + 60));
    expect(after, greaterThan(225));
  });

  test('brightness and contrast move the mean', () {
    double mean(Uint8List png) {
      final m = cv.imdecode(png, cv.IMREAD_GRAYSCALE);
      final v = cv.mean(m).val1;
      m.dispose();
      return v;
    }

    final base = mean(
      filterImageSync(shadowed, ScanFilter.original, ext: '.png'),
    );
    expect(
      mean(
        filterImageSync(
          shadowed,
          ScanFilter.original,
          brightness: 0.2,
          ext: '.png',
        ),
      ),
      greaterThan(base + 10),
    );
    expect(
      mean(
        filterImageSync(
          shadowed,
          ScanFilter.original,
          brightness: -0.2,
          ext: '.png',
        ),
      ),
      lessThan(base - 10),
    );
  });

  test('a preview fits 64 × 80 and renders in < 150 ms', () async {
    // Warm up the native library once.
    filterImageSync(letter, ScanFilter.original, fit: previewSize);
    for (final f in ScanFilter.values) {
      final watch = Stopwatch()..start();
      final jpg = filterImageSync(letter, f, fit: previewSize);
      watch.stop();
      final m = cv.imdecode(jpg, cv.IMREAD_UNCHANGED);
      expect(
        m.cols <= 64 && m.rows <= 80,
        isTrue,
        reason: '${f.name}: ${m.cols} × ${m.rows}',
      );
      expect(watch.elapsedMilliseconds, lessThan(150), reason: f.name);
      m.dispose();
    }
  });

  test(
    'full resolution is kept without fit, and the isolate API matches',
    () async {
      final page = cv.imdecode(letter, cv.IMREAD_COLOR);
      final out = cv.imdecode(
        await filterImage(letter, ScanFilter.autoColour, ext: '.png'),
        cv.IMREAD_COLOR,
      );
      expect((out.cols, out.rows), (page.cols, page.rows));
      page.dispose();
      out.dispose();
    },
  );

  test('a file that is not an image is a FormatException', () {
    expect(
      () => filterImageSync(Uint8List.fromList([1, 2, 3]), ScanFilter.original),
      throwsFormatException,
    );
  });
}

/// The mean absolute difference per pixel (0–255) of two encoded images.
double _meanDiff(Uint8List a, Uint8List b) {
  final ma = cv.imdecode(a, cv.IMREAD_UNCHANGED);
  final mb = cv.imdecode(b, cv.IMREAD_UNCHANGED);
  expect((ma.cols, ma.rows, ma.channels), (mb.cols, mb.rows, mb.channels));
  final diff = cv.absDiff(ma, mb);
  final s = cv.sum(diff);
  final total = s.val1 + s.val2 + s.val3 + s.val4;
  final mean = total / (ma.cols * ma.rows * ma.channels);
  for (final m in [ma, mb, diff]) {
    m.dispose();
  }
  return mean;
}
