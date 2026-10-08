import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:doc_vision/doc_vision.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:qpdf_ffi/qpdf_ffi.dart';
import 'package:test/test.dart';

/// The shared sample corpus (DK-0023), from the repo root.
String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

List<String> _check(String path, JobContext context) =>
    QpdfService.run(() => Qpdf.check(path));

/// Reads every page as the same two words. It runs on the OCR worker.
class _FakeOcr implements OcrEngine {
  const _FakeOcr();

  @override
  String get name => 'fake';

  static const _page = PageOcr('fake', [
    (
      text: 'Jahresabrechnung',
      box: (left: 0.1, top: 0.2, width: 0.4, height: 0.03),
      confidence: 0.95,
    ),
    (
      text: 'Stadtwerke',
      box: (left: 0.1, top: 0.08, width: 0.3, height: 0.03),
      confidence: 0.9,
    ),
  ], PageQuality.ok);

  @override
  Future<PageOcr> recognize(
    String imagePath, {
    OcrLanguage language = OcrLanguage.auto,
  }) async => _page;

  @override
  Future<PageOcr> recognizeRaster(
    Raster raster, {
    OcrLanguage language = OcrLanguage.auto,
    required Directory scratch,
  }) async {
    // A rendered A4 page at 300 dpi reaches the worker as pixels. (No
    // expect here: this runs on the worker, outside the test.)
    if ((raster.width, raster.height) != (2480, 3508)) {
      throw StateError('got ${raster.width}x${raster.height}');
    }
    return _page;
  }

  @override
  Future<void> close() async {}
}

Future<OcrEngine> _fake(OcrAssets? assets) async => const _FakeOcr();

void main() {
  setUpAll(pdfrxInitialize);
  late Directory dir, outDir;
  late IsolatePool pool;
  late DokuloDatabase db;
  late JobQueue queue;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dk_ocr_job_');
    outDir = Directory('${dir.path}/out')..createSync();
    pool = IsolatePool(tempRoot: Directory('${dir.path}/jobs')..createSync());
    db = DokuloDatabase.memory();
    queue = JobQueue(pool, db, ToolRegistry.app());
    OcrJob.assets = () async => null;
    OcrJob.engine = _fake;
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  final scan = fixture('scanned-letters-bundle.pdf');
  OcrInput input(List<String> files, {String? password, List<int>? pages}) =>
      OcrInput(
        files: files,
        outputDir: outDir.path,
        suffix: ' – searchable',
        password: password,
        pages: pages,
      );

  Future<String> text(String path, int page, {String? password}) async =>
      (await PdfEngine.pageText(path, page, password: password)).text;

  test('ocr is registered; its input survives JSON without the password', () {
    final job = ToolRegistry.app()['ocr'];
    final json = job.encode(input([scan], pages: [0, 2]));
    expect(job.encode(job.decode(json)), json);
    expect(job.inputFiles(job.decode(json)), [scan]);
    expect(
      job.encode(input([scan], password: 'geheim')),
      isNot(contains('password')),
    );
  });

  test('a scan becomes searchable: words on every page, same look, checks clean, original untouched', () async {
    final original = File(scan).readAsBytesSync();
    final run = await queue.start('ocr', input([scan]));
    final progress = run.progress.toList();
    final output = await run.result as OneFile;

    expect(
      output.path,
      '${outDir.path}/scanned-letters-bundle – searchable.pdf',
    );
    expect((await PdfEngine.inspect(output.path)).pageCount, 6);
    for (var p = 0; p < 6; p++) {
      expect(
        await text(output.path, p),
        contains('Jahresabrechnung'),
        reason: 'page $p',
      );
    }
    expect(
      await pool.run(Lane.qpdf, _check, output.path).result,
      isEmpty,
      reason: 'qpdf --check',
    );
    expect(
      File(scan).readAsBytesSync(),
      original,
      reason: 'the original is never touched',
    );
    expect((await progress).map((p) => p.pageIndex), [0, 1, 2, 3, 4, 5]);

    // Invisible text: the page looks as it did.
    final before = await PdfEngine.render(scan, 0, dpi: 30),
        after = await PdfEngine.render(output.path, 0, dpi: 30);
    expect(after.bgra, before.bgra);
    expect(
      dir.listSync(recursive: true).where((f) => f.path.endsWith('.bgra')),
      isEmpty,
      reason: 'pixels cleaned up',
    );
  });

  test('"Pages: Choose…" reads only those pages', () async {
    final output =
        await (await queue.start('ocr', input([scan], pages: [0, 2]))).result
            as OneFile;
    for (var p = 0; p < 6; p++) {
      expect(
        await text(output.path, p),
        p == 0 || p == 2 ? contains('Jahresabrechnung') : isEmpty,
        reason: 'page $p',
      );
    }
  });

  test('pages that have text keep it and get no second layer', () async {
    final output =
        await (await queue.start(
              'ocr',
              input([fixture('Invoice INV-2026-014.pdf')]),
            )).result
            as OneFile;
    expect(await text(output.path, 0), contains('Invoice INV-2026-014'));
    expect(await text(output.path, 0), isNot(contains('Jahresabrechnung')));
  });

  test(
    'a locked file with the right password works, and stays locked',
    () async {
      final locked = fixture('encrypted-aes256.pdf');
      final output =
          await (await queue.start(
                'ocr',
                input([locked], password: 'dokulo'),
              )).result
              as OneFile;
      expect(
        await text(output.path, 0, password: 'dokulo'),
        contains('Invoice INV-2026-014'),
      );
      await expectLater(
        PdfEngine.inspect(output.path),
        throwsA(isA<DocError>()),
        reason: 'the output keeps the encryption',
      );
    },
  );

  test('a wrong password fails as "locked" and writes nothing', () async {
    final run = await queue.start(
      'ocr',
      input([fixture('encrypted-aes256.pdf')], password: 'wrong'),
    );
    await expectLater(
      run.result,
      throwsA(
        isA<JobFailed>().having(
          (e) => e.message,
          'message',
          contains('DocError(locked'),
        ),
      ),
    );
    expect(outDir.listSync(), isEmpty);
  });

  test('cancel leaves no files and the original untouched', () async {
    final original = File(scan).readAsBytesSync();
    final run = await queue.start('ocr', input([scan, scan]));
    await run.progress.first;
    run.cancel();
    await expectLater(run.result, throwsA(isA<JobCancelled>()));
    expect(outDir.listSync(), isEmpty);
    expect(File(scan).readAsBytesSync(), original);
  });
}
