import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:doc_vision/doc_vision.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

import '../../../doc_vision/test/ocr/python_onnx_runner.dart';

/// The shared sample corpus (DK-0023), from the repo root.
String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

final _repo = Directory.current.parent.parent.path;

/// PP-OCRv5 through python onnxruntime, made on the ONNX worker (a process
/// can't be sent to it).
Future<OcrEngine> _python(OcrAssets? assets) async {
  final runner = await PythonOnnxRunner.start(_repo);
  final dictionary = File(
    '$_repo/packages/doc_vision/assets/ocr/ppocrv5_latin_dict.txt',
  ).readAsLinesSync();
  return PpOcrEngine(PpOcr(runner!, dictionary));
}

/// Rotate PDF's look for sideways pages (DK-1102).
void main() {
  setUpAll(pdfrxInitialize);
  late Directory dir;
  late DokuloDatabase db;
  late JobQueue queue;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dk_rotate_detect_');
    db = DokuloDatabase.memory();
    queue = JobQueue(
      IsolatePool(tempRoot: Directory('${dir.path}/jobs')..createSync()),
      db,
      ToolRegistry.app(),
    );
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  /// [file]'s pages, each turned as given (clockwise quarter turns).
  Future<String> turned(String file, List<int> turns) async {
    final out = '${dir.path}/turned_${turns.join()}.pdf';
    await PdfEngine.assemble([
      for (final (p, t) in turns.indexed)
        PageSource(file, p, addQuarterTurns: t),
    ], out);
    return out;
  }

  Future<Map<String, Object?>> detect(String file) async {
    final run = await queue.start(
      'rotate',
      RotateInput(
        file: file,
        turns: const {},
        outputDir: dir.path,
        suffix: '',
        detect: true,
      ),
    );
    final out = await run.result as OneFile;
    expect(out.path, file, reason: 'nothing written');
    return (out.facts['sideways']! as Map).cast<String, Object?>();
  }

  test('pages with text: a turned page says how to turn it back', () async {
    final contract = fixture('Mietvertrag Musterstraße 12.pdf');
    expect(await PdfEngine.textTurns(contract, 0), 0);
    // Page 1 shown a quarter clockwise needs three more; page 2 upside down
    // needs two; page 3 is upright.
    expect(await detect(await turned(contract, [1, 2, 0])), {'0': 3, '1': 2});
  });

  test('scans: PP-OCR tells sideways and upside down', () async {
    if (await PythonOnnxRunner.start(_repo) case final probe?) {
      await probe.close();
    } else {
      markTestSkipped(
        'needs tools/fetch_ocr_models.py and `pip install onnxruntime numpy`',
      );
      return;
    }
    final engine = OcrJob.engine, assets = OcrJob.assets;
    OcrJob.engine = _python;
    OcrJob.assets = () async => null;
    addTearDown(() {
      OcrJob.engine = engine;
      OcrJob.assets = assets;
    });
    final bundle = fixture('scanned-letters-bundle.pdf');
    expect(await detect(await turned(bundle, [1, 0, 2])), {'0': 3, '2': 2});
  }, timeout: const Timeout(Duration(minutes: 3)));
}
