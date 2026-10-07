import 'dart:io';
import 'dart:typed_data';

import 'package:doc_vision/doc_vision.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'python_onnx_runner.dart';

const repo = '../..';

class _NoModels implements OnnxRunner {
  @override
  Future<(Float32List, List<int>)> run(
    String model,
    Float32List input,
    List<int> shape,
  ) => throw UnimplementedError();
}

void main() {
  group('post-processing', () {
    test('DB lines: three text regions, grown by the unclip distance, in reading order', () {
      const w = 100, h = 40;
      final map = Float32List(w * h);
      void fill(int x0, int y0, int x1, int y1, double p) {
        for (var y = y0; y < y1; y++) {
          for (var x = x0; x < x1; x++) {
            map[y * w + x] = p;
          }
        }
      }

      fill(60, 5, 90, 15, 0.9); // right, first line
      fill(5, 5, 50, 15, 0.9); // left, first line
      fill(5, 25, 40, 33, 0.8); // second line
      fill(70, 30, 72, 32, 0.9); // a speck: too small
      fill(50, 30, 60, 38, 0.4); // above the threshold but not confident enough

      final boxes = [
        for (final q in PpOcr.linesFromProbability(map, w, h)) q.bounds(w, h),
      ];
      expect(boxes, hasLength(3));
      expect(boxes[0].left, lessThan(5));
      expect(boxes[1].left, greaterThan(50));
      expect(boxes[2].top, greaterThan(15));
      // 45 × 10 region: d = 450 · 1.5 / 110 ≈ 6.1
      expect(boxes[0], (left: 0, top: 0, right: 57, bottom: 22));
    });

    test(
      'greedy CTC drops blanks and repeats, maps the last class to a space',
      () {
        final ocr = PpOcr(_NoModels(), [
          'a',
          'b',
        ]); // classes: blank, a, b, space
        final steps = [1, 1, 0, 1, 3, 2, 2]; // a a _ a ␣ b b
        final probs = Float32List(steps.length * 4);
        for (final (t, c) in steps.indexed) {
          probs[t * 4 + c] = 0.9;
        }
        final (text, confidence) = ocr.decodeCtc(probs, steps.length, 4, 0);
        expect(text, 'aa b');
        expect(confidence, closeTo(0.9, 1e-6));
      },
    );

    test('BGRA and grey become BGR', () {
      final fromBgra = Raster.fromBgra(
        1,
        1,
        Uint8List.fromList([10, 20, 30, 255]),
      );
      expect(fromBgra.bgr, [10, 20, 30]);
      expect(Raster.fromGrey(2, 1, Uint8List.fromList([7, 9])).bgr, [
        7,
        7,
        7,
        9,
        9,
        9,
      ]);
    });
  });

  group('the real models (python onnxruntime on the development machine)', () {
    PythonOnnxRunner? runner;
    final models = Directory('$repo/packages/doc_vision/assets/ocr');
    setUpAll(() async {
      if (models.existsSync()) runner = await PythonOnnxRunner.start(repo);
    });
    tearDownAll(() async => runner?.close());

    test('a scanned letter: every line, in reading order', () async {
      if (runner == null) {
        markTestSkipped(
          'needs tools/fetch_ocr_models.py and `pip install onnxruntime numpy`',
        );
        return;
      }
      final decoded = img.decodeJpg(
        File('test/fixtures/ocr/letter-de.jpg').readAsBytesSync(),
      )!;
      final grey = img.grayscale(decoded);
      final raster = Raster.fromGrey(
        grey.width,
        grey.height,
        Uint8List.fromList([for (final p in grey) p.r.toInt()]),
      );
      final dictionary = File('${models.path}/ppocrv5_latin_dict.txt')
          .readAsLinesSync();

      final lines = await PpOcr(runner!, dictionary).recognize(raster);
      final texts = lines.map((l) => l.text).toList();
      printOnFailure(lines.join('\n'));

      expect(
        texts,
        containsAll([
          'Stadtwerke Musterstadt',
          'Jahresabrechnung Strom 2025',
          'Sehr geehrter Herr Mustermann,',
          'service@example.com.',
          'Zahlungen bitte auf IBAN DE00 0000 0000 0000 0000 00.',
          'Seite 1 von 2',
          'Herrn Max Mustermann',
          'Musterstraße 12',
          '80331 München',
          'Mit freundlichen Grüßen',
        ]),
      );
      expect(
        texts.indexOf('Stadtwerke Musterstadt'),
        lessThan(texts.indexOf('Jahresabrechnung Strom 2025')),
      );
      final head = lines.firstWhere((l) => l.text == 'Stadtwerke Musterstadt');
      expect(head.confidence, greaterThan(0.9));
      expect(head.box.left, lessThan(150));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
