import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:qpdf_ffi/qpdf_ffi.dart';
import 'package:test/test.dart';

/// The shared sample corpus (DK-0023), from the repo root.
String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

List<String> _check(String path, JobContext context) =>
    QpdfService.run(() => Qpdf.check(path));

void main() {
  setUpAll(pdfrxInitialize);
  late Directory dir, outDir;
  late IsolatePool pool;
  late DokuloDatabase db;
  late JobQueue queue;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dk_crop_job_');
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

  CropInput input(
    String file, {
    Map<int, CropInsets> insets = const {},
    bool auto = false,
  }) => CropInput(
    file: file,
    outputDir: outDir.path,
    suffix: ' – cropped',
    insets: insets,
    auto: auto,
  );

  test('the chosen page shrinks by its insets, the others stay; the text '
      'stays in the file; checks clean, original untouched', () async {
    final before = File(contract).readAsBytesSync();
    const cut = (left: 0.1, top: 0.2, right: 0.1, bottom: 0.0);
    final job = ToolRegistry.app()['crop'];
    final json = job.encode(input(contract, insets: {0: cut}));
    expect(job.encode(job.decode(json)), json);

    final out =
        await (await queue.start(
              'crop',
              input(contract, insets: {0: cut}),
            )).result
            as OneFile;
    expect(
      out.path,
      '${outDir.path}/Mietvertrag Musterstraße 12 – cropped.pdf',
    );
    final a = (await PdfEngine.inspect(contract)).pages;
    final b = (await PdfEngine.inspect(out.path)).pages;
    expect(b[0].width, closeTo(a[0].width * 0.8, 0.5));
    expect(b[0].height, closeTo(a[0].height * 0.8, 0.5));
    expect(b[1].width, a[1].width);
    await expectLater(
      pool.run(Lane.qpdf, _check, out.path).result,
      completion(isEmpty),
    );
    expect(File(contract).readAsBytesSync(), before);
  });

  test('a turned page is cut where it shows the cut', () async {
    final turned = '${dir.path}/turned.pdf';
    await PdfEngine.assemble([
      PageSource(contract, 0, addQuarterTurns: 1),
    ], turned);
    final shown = (await PdfEngine.inspect(turned)).pages.single;
    final out =
        await (await queue.start(
              'crop',
              input(
                turned,
                insets: {0: (left: 0.5, top: 0.0, right: 0.0, bottom: 0.0)},
              ),
            )).result
            as OneFile;
    final page = (await PdfEngine.inspect(out.path)).pages.single;
    expect(page.width, closeTo(shown.width / 2, 0.5));
    expect(page.height, closeTo(shown.height, 0.5));
  });

  test('Auto margins trims the white around the text', () async {
    final out =
        await (await queue.start('crop', input(contract, auto: true))).result
            as OneFile;
    final a = (await PdfEngine.inspect(contract)).pages;
    final b = (await PdfEngine.inspect(out.path)).pages;
    for (var p = 0; p < a.length; p++) {
      expect(b[p].width, lessThan(a[p].width));
      expect(b[p].width, greaterThan(a[p].width / 3));
    }
  });
}
