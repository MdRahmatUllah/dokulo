import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

/// The shared sample corpus (DK-0023), from the repo root.
String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

void main() {
  setUpAll(pdfrxInitialize);
  late Directory dir, outDir;
  late DokuloDatabase db;
  late JobQueue queue;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dk_pdf2img_job_');
    outDir = Directory('${dir.path}/out')..createSync();
    final pool = IsolatePool(
      tempRoot: Directory('${dir.path}/jobs')..createSync(),
    );
    db = DokuloDatabase.memory();
    queue = JobQueue(pool, db, ToolRegistry.app());
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  final contract = fixture('Mietvertrag Musterstraße 12.pdf'); // 3 pages
  final long = fixture('long-300-pages.pdf');

  Pdf2ImgInput input(
    String file, {
    bool png = false,
    double dpi = 150,
    List<int>? pages,
  }) => Pdf2ImgInput(
    file: file,
    outputDir: outDir.path,
    suffix: ' – Seite',
    png: png,
    dpi: dpi,
    pages: pages,
  );

  test('every page a JPG at the dpi, numbered; the input survives JSON; '
      'the original untouched', () async {
    final before = File(contract).readAsBytesSync();
    final job = ToolRegistry.app()['pdf2img'];
    final json = job.encode(input(contract, png: true, pages: [2]));
    expect(job.encode(job.decode(json)), json);

    final out =
        await (await queue.start('pdf2img', input(contract))).result
            as ManyFiles;
    expect(out.paths, [
      for (var n = 1; n <= 3; n++)
        '${outDir.path}/Mietvertrag Musterstraße 12 – Seite $n.jpg',
    ]);
    final page = (await PdfEngine.inspect(contract)).pages.first;
    final first = img.decodeJpg(File(out.paths.first).readAsBytesSync())!;
    expect(first.width, (page.width * 150 / 72).round());
    expect(File(contract).readAsBytesSync(), before);
  });

  test('chosen pages as PNG, padded so they sort', () async {
    final out =
        await (await queue.start(
              'pdf2img',
              input(long, png: true, dpi: 72, pages: [8, 0]),
            )).result
            as ManyFiles;
    expect(out.paths, [
      '${outDir.path}/long-300-pages – Seite 009.png',
      '${outDir.path}/long-300-pages – Seite 001.png',
    ]);
    expect(img.decodePng(File(out.paths.first).readAsBytesSync()), isNotNull);
  });

  test('12 pages at 150 dpi fast (target < 5 s)', () async {
    final watch = Stopwatch()..start();
    final out =
        await (await queue.start(
              'pdf2img',
              input(long, pages: [for (var p = 0; p < 12; p++) p]),
            )).result
            as ManyFiles;
    watch.stop();
    expect(out.paths, hasLength(12));
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test('a page that does not exist is refused, leaving nothing', () async {
    await expectLater(
      (await queue.start('pdf2img', input(contract, pages: [5]))).result,
      throwsA(isA<JobFailed>()),
    );
    expect(outDir.listSync(), isEmpty);
  });
}
