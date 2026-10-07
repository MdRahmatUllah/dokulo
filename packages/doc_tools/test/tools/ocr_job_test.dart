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

/// Reads every page as the same two words, and counts its calls.
class _FakeOcr implements OcrEngine {
  var calls = 0;

  @override
  String get name => 'fake';

  @override
  Future<PageOcr> recognize(
    String imagePath, {
    OcrLanguage language = OcrLanguage.auto,
  }) async {
    calls++;
    expect(File(imagePath).existsSync(), isTrue, reason: 'a rendered page');
    return const PageOcr('fake', [
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
  }
}

void main() {
  setUpAll(pdfrxInitialize);
  late Directory dir, outDir;
  late IsolatePool pool;
  late DokuloDatabase db;
  late JobQueue queue;
  late _FakeOcr ocr;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dk_ocr_job_');
    outDir = Directory('${dir.path}/out')..createSync();
    pool = IsolatePool(tempRoot: Directory('${dir.path}/jobs')..createSync());
    db = DokuloDatabase.memory();
    queue = JobQueue(pool, db, ToolRegistry.app());
    ocr = _FakeOcr();
    OcrJob.engine = () async => ocr;
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  final scan = fixture('scanned-letters-bundle.pdf');
  OcrInput input(List<String> files, {String? password}) => OcrInput(
    files: files,
    outputDir: outDir.path,
    suffix: ' – searchable',
    password: password,
  );

  test('ocr is registered and its input survives JSON', () {
    final job = ToolRegistry.app()['ocr'];
    final json = job.encode(input([scan]));
    expect(job.encode(job.decode(json)), json);
    expect(job.inputFiles(job.decode(json)), [scan]);
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
    expect(ocr.calls, 6, reason: 'every page is a picture');
    final info = await PdfEngine.inspect(output.path);
    expect(info.pageCount, 6);
    for (var p = 0; p < 6; p++) {
      expect(
        (await PdfEngine.pageText(output.path, p)).text,
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
  });

  test('pages that have text keep it and are not read again', () async {
    final output =
        await (await queue.start(
              'ocr',
              input([fixture('Invoice INV-2026-014.pdf')]),
            )).result
            as OneFile;
    expect(ocr.calls, 0);
    expect(
      (await PdfEngine.pageText(output.path, 0)).text,
      contains('Invoice INV-2026-014'),
    );
    expect(
      (await PdfEngine.pageText(output.path, 0)).text,
      isNot(contains('Jahresabrechnung')),
    );
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
}
