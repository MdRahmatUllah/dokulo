import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:qpdf_ffi/qpdf_ffi.dart';
import 'package:test/test.dart';

/// The shared sample corpus (DK-0023), from the repo root.
String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

List<String> _check(String path, JobContext context) =>
    QpdfService.run(() => Qpdf.check(path));

/// Add page numbers (DK-0480), Add watermark (DK-0486).
void main() {
  setUpAll(pdfrxInitialize);
  late Directory dir, outDir;
  late IsolatePool pool;
  late DokuloDatabase db;
  late JobQueue queue;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dk_stamp_jobs_');
    outDir = Directory('${dir.path}/out')..createSync();
    pool = IsolatePool(tempRoot: Directory('${dir.path}/jobs')..createSync());
    db = DokuloDatabase.memory();
    queue = JobQueue(pool, db, ToolRegistry.app());
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  final contract = fixture('Mietvertrag Musterstraße 12.pdf'); // 3 pages
  final long = fixture('long-300-pages.pdf');

  Future<List<String>> texts(String path) => PdfEngine.pageTexts(path);
  Future<void> checks(String path) async =>
      expect(await pool.run(Lane.qpdf, _check, path).result, isEmpty);

  test(
    'page numbers: "Seite n von N" from the start number, the first '
    'page skipped; the text kept; checks clean, original untouched',
    () async {
      final before = File(contract).readAsBytesSync();
      final input = PageNumbersInput(
        files: [contract],
        outputDir: outDir.path,
        suffix: ' – nummeriert',
        format: 'Seite {n} von {total}',
        startAt: 5,
        skipFirst: true,
      );
      final job = ToolRegistry.app()['pagenum'];
      expect(job.encode(job.decode(job.encode(input))), job.encode(input));
      final out = await (await queue.start('pagenum', input)).result as OneFile;
      expect(
        out.path,
        '${outDir.path}/Mietvertrag Musterstraße 12 – nummeriert.pdf',
      );
      final t = await texts(out.path);
      final original = await texts(contract);
      expect(t[0], isNot(contains('Seite 5 von 7')));
      expect(t[1], contains('Seite 6 von 7'));
      expect(t[2], contains('Seite 7 von 7'));
      // Bottom centre, 24 pt in: PDF points from the bottom-left.
      final page = await PdfEngine.pageText(out.path, 1);
      final box = page.charBoxes[page.text.indexOf('Seite 6')];
      final width = (await PdfEngine.inspect(out.path)).pages[1].width;
      expect(box.bottom, inInclusiveRange(20, 40));
      expect(box.left, inInclusiveRange(width / 2 - 60, width / 2));
      for (final (i, page) in original.indexed) {
        expect(t[i], contains(page.trim().split('\n').first.trim()));
      }
      await checks(out.path);
      expect(File(contract).readAsBytesSync(), before);
    },
  );

  test('page numbers: 100 pages fast (target < 3 s)', () async {
    final long100 = '${dir.path}/long100.pdf';
    await PdfEngine.assemble([
      for (var p = 0; p < 100; p++) PageSource(long, p),
    ], long100);
    final watch = Stopwatch()..start();
    final out =
        await (await queue.start(
              'pagenum',
              PageNumbersInput(
                files: [long100],
                outputDir: outDir.path,
                suffix: ' – n',
              ),
            )).result
            as OneFile;
    watch.stop();
    expect((await texts(out.path))[99], contains('100'));
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
  });

  test('watermark: text on the chosen pages only; behind, an image', () async {
    final out =
        await (await queue.start(
              'watermark',
              WatermarkInput(
                files: [contract],
                outputDir: outDir.path,
                suffix: ' – watermarked',
                text: 'ENTWURF',
                pages: {0, 2},
                tiled: true,
              ),
            )).result
            as OneFile;
    final t = await texts(out.path);
    expect(t[0], contains('ENTWURF'));
    expect(t[1], isNot(contains('ENTWURF')));
    expect(t[2], contains('ENTWURF'));
    await checks(out.path);

    final logo = File('${dir.path}/logo.png')
      ..writeAsBytesSync(img.encodePng(img.Image(width: 40, height: 20)));
    final behind =
        await (await queue.start(
              'watermark',
              WatermarkInput(
                files: [contract],
                outputDir: outDir.path,
                suffix: ' – logo',
                image: logo.path,
                size: 0.5,
                behind: true,
              ),
            )).result
            as OneFile;
    expect((await PdfEngine.inspect(behind.path)).pageCount, 3);
    expect(await texts(behind.path), await texts(contract));
    await checks(behind.path);
  });
}
