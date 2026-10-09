import 'dart:typed_data';

import 'package:doc_vision/doc_vision.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import 'quad_detector_test.dart' show scene;

/// [n] words, together covering [area] of the photo.
List<Word> words(int n, double area) => [
  for (var i = 0; i < n; i++)
    (
      text: 'w$i',
      box: (left: 0.1, top: 0.1, width: area / n, height: 1.0),
      confidence: 0.9,
    ),
];

Quad rect(double w, double h) =>
    Quad((x: 0, y: 0), (x: w, y: 0), (x: w, y: h), (x: 0, y: h));

void main() {
  group('documentScore', () {
    double score(List<Word> w, [Quad? q]) =>
        documentScore(width: 300, height: 400, words: w, quad: q);

    test('a photographed A4 page with text scores near 1', () {
      expect(score(words(30, 0.2), rect(280, 396)), closeTo(1, 0.01));
    });

    test('a text screenshot (no page edges) is still a document', () {
      expect(score(words(30, 0.2)), greaterThanOrEqualTo(documentThreshold));
    });

    test('a square frame without text is not', () {
      expect(score(const [], rect(300, 300)), lessThan(documentThreshold));
    });

    test('a sign with two big words is not', () {
      expect(score(words(2, 0.3)), lessThan(documentThreshold));
    });

    test('a receipt (long and thin, some text) is', () {
      expect(score(words(12, 0.06), rect(100, 380)), greaterThan(0.5));
    });
  });

  group('decodeForScoring', () {
    test('finds the page in a JPEG', () {
      final img = scene([(200, 180), (760, 200), (740, 1100), (180, 1080)]);
      final (ok, jpeg) = cv.imencode('.jpg', img);
      img.dispose();
      expect(ok, isTrue);
      final d = decodeForScoring(jpeg)!;
      expect((d.raster.width, d.raster.height), (960, 1280));
      expect(d.raster.bgr.length, 960 * 1280 * 3);
      expect(d.quad, isNotNull);
    });

    test('not an image: null', () {
      expect(decodeForScoring(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });
}
