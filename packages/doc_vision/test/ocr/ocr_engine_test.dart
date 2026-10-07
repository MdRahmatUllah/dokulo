import 'dart:io';
import 'dart:typed_data';

import 'package:doc_vision/doc_vision.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vision_ocr/vision_ocr.dart';

import 'python_onnx_runner.dart';

const repo = '../..';
const fixtures = 'test/fixtures/ocr';

/// Vision on a phone: a scripted answer, or "unavailable".
class _FakeVision extends VisionOcr {
  _FakeVision([this.words]);
  final List<OcrWord>? words;
  List<String>? hintsSeen;

  @override
  Future<List<OcrWord>> recognize(
    String imagePath, {
    List<String> languages = const [],
  }) async {
    hintsSeen = languages;
    if (words == null) {
      throw const VisionOcrException(VisionOcrError.unavailable);
    }
    return words!;
  }
}

class _Fixed implements OcrEngine {
  @override
  String get name => 'fixed';

  @override
  Future<PageOcr> recognize(
    String imagePath, {
    OcrLanguage language = OcrLanguage.auto,
  }) async => PageOcr(name, const [], PageQuality.noText);
}

Raster scan(String name) =>
    decodeRaster(File('$fixtures/$name').readAsBytesSync());

void main() {
  test('character error rate: edit distance over the reference length', () {
    expect(characterErrorRate('Grüßen', 'Grüßen'), 0);
    expect(characterErrorRate('Herrn', 'Herrm'), closeTo(0.2, 1e-9));
    expect(characterErrorRate('abc', ''), 1);
    expect(characterErrorRate('abcd', 'abxcd'), closeTo(0.25, 1e-9));
  });

  test("a line's words get their share of its box", () {
    final words = PpOcrEngine.wordsOf(
      const OcrLine('Total 19.45', (
        left: 100,
        top: 50,
        right: 210,
        bottom: 70,
      ), 0.9),
      1000,
      500,
    );
    expect(words.map((w) => w.text), ['Total', '19.45']);
    expect(words[0].box.left, closeTo(0.1, 1e-9));
    expect(
      words[1].box.left,
      closeTo(0.16, 1e-9),
    ); // 6 characters in, 10 px each
    expect(words[1].box.width, closeTo(0.05, 1e-9));
    expect(words[0].box.top, 0.1);
    expect(words[0].confidence, 0.9);
  });

  test('page quality: blur first, then no text, then low confidence', () {
    Word w(double c) => (
      text: 'x',
      box: (left: 0.0, top: 0.0, width: 0.1, height: 0.1),
      confidence: c,
    );
    expect(judge([w(0.99)], blurLimit - 1), PageQuality.tooBlurry);
    expect(judge(const [], blurLimit + 1), PageQuality.noText);
    expect(judge([w(0.6), w(0.7)], blurLimit + 1), PageQuality.lowConfidence);
    expect(judge([w(0.9), w(0.95)], blurLimit + 1), PageQuality.ok);
  });

  test(
    'a sharp scan passes the blur limit; the same scan blurred does not',
    () {
      final sharp = scan('letter-de.jpg');
      final blurred = decodeRaster(
        img.encodePng(
          img.gaussianBlur(
            img.decodeJpg(File('$fixtures/letter-de.jpg').readAsBytesSync())!,
            radius: 4,
          ),
        ),
      );
      printOnFailure(
        'sharpness: sharp ${sharpness(sharp)}, blurred ${sharpness(blurred)}',
      );
      expect(sharpness(sharp), greaterThan(blurLimit));
      expect(sharpness(blurred), lessThan(blurLimit));
    },
  );

  test(
    'Vision: words as Vision gives them, language hints passed on',
    () async {
      final vision = _FakeVision([
        const OcrWord('Hallo', (
          left: 0.1,
          top: 0.2,
          width: 0.1,
          height: 0.02,
        ), 0.97),
      ]);
      final page = await VisionEngine(
        fallback: _Fixed(),
        vision: vision,
      ).recognize('$fixtures/letter-de.jpg', language: OcrLanguage.german);
      expect(page.engine, 'vision');
      expect(page.text, 'Hallo');
      expect(page.quality, PageQuality.ok);
      expect(vision.hintsSeen, ['de-DE']);
    },
  );

  test('Vision unavailable: the fallback engine reads the page', () async {
    final page = await VisionEngine(
      fallback: _Fixed(),
      vision: _FakeVision(),
    ).recognize('$fixtures/letter-de.jpg');
    expect(page.engine, 'fixed');
  });

  test('not an image', () async {
    final file = File('${Directory.systemTemp.path}/dk_not_an_image.jpg')
      ..writeAsStringSync('nope');
    addTearDown(file.deleteSync);
    expect(
      PpOcrEngine(PpOcr(_Unused(), const [])).recognize(file.path),
      throwsA(isA<OcrException>()),
    );
  });

  group('PP-OCRv5 on the hand-labelled set (python onnxruntime)', () {
    PythonOnnxRunner? runner;
    late List<String> dictionary;
    setUpAll(() async {
      if (Directory('$repo/packages/doc_vision/assets/ocr').existsSync()) {
        runner = await PythonOnnxRunner.start(repo);
        dictionary = File(
          '$repo/packages/doc_vision/assets/ocr/ppocrv5_latin_dict.txt',
        ).readAsLinesSync();
      }
    });
    tearDownAll(() async => runner?.close());

    // The measured rates (docs/compliance/ai-models.md, PP-OCRv5); a change
    // that makes them worse fails here.
    for (final (page, limit) in [('letter-de', 0.01), ('receipt-en', 0.01)]) {
      test('$page: CER at most $limit, page quality ok', () async {
        if (runner == null) {
          markTestSkipped(
            'needs tools/fetch_ocr_models.py and `pip install onnxruntime numpy`',
          );
          return;
        }
        final result = await PpOcrEngine(PpOcr(runner!, dictionary))
            .recognize('$fixtures/$page.jpg');
        final truth = File('$fixtures/$page.txt').readAsLinesSync().join(' ');
        final cer = characterErrorRate(truth, result.text);
        printOnFailure('CER $cer\n${result.text}');
        printOnFailure(
          '$page: CER ${(cer * 100).toStringAsFixed(2)} %, mean confidence ${result.meanConfidence.toStringAsFixed(3)}',
        );
        expect(cer, lessThanOrEqualTo(limit));
        expect(result.quality, PageQuality.ok);
      }, timeout: const Timeout(Duration(minutes: 2)));
    }
  });
}

class _Unused implements OnnxRunner {
  @override
  Future<(Float32List, List<int>)> run(
    String model,
    Float32List input,
    List<int> shape,
  ) => throw StateError('unused');
}
