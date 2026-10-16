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

void main() {
  setUpAll(pdfrxInitialize);
  late Directory dir, outDir;
  late IsolatePool pool;
  late DokuloDatabase db;
  late JobQueue queue;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dk_merge_job_');
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
  final invoice = fixture('Invoice INV-2026-014.pdf'); // 1 page
  final long = fixture('long-300-pages.pdf');
  final locked = fixture('encrypted-aes256.pdf'); // password "dokulo"

  MergeInput input(
    List<String> files, {
    Map<int, String> ranges = const {},
    Map<String, String> passwords = const {},
  }) => MergeInput(
    files: files,
    outputDir: outDir.path,
    suffix: ' – merged',
    ranges: ranges,
    passwords: passwords,
  );

  Future<List<String>> texts(String path) => PdfEngine.pageTexts(path);

  test('merge is registered; its input survives JSON without passwords', () {
    final job = ToolRegistry.app()['merge'];
    final json = job.encode(
      input([contract, locked], ranges: {0: '2-3'}, passwords: {locked: 'x'}),
    );
    expect(job.encode(job.decode(json)), json);
    expect(job.inputFiles(job.decode(json)), [contract, locked]);
    expect(json.toString(), isNot(contains('password')));
  });

  test('the pages in the cards\' order, ranges kept, named after the first '
      'file; opens, checks clean, inputs untouched', () async {
    final before = [
      File(contract).readAsBytesSync(),
      File(invoice).readAsBytesSync(),
    ];
    final run = await queue.start(
      'merge',
      input([invoice, contract, invoice], ranges: {1: '3,1'}),
    );
    final progress = await run.progress.toList();
    final output = await run.result as OneFile;

    expect(output.path, '${outDir.path}/Invoice INV-2026-014 – merged.pdf');
    final want = [
      ...await texts(invoice),
      (await texts(contract))[2],
      (await texts(contract))[0],
      ...await texts(invoice),
    ];
    expect(await texts(output.path), want);
    expect(await pool.run(Lane.qpdf, _check, output.path).result, isEmpty);
    expect(progress, isNotEmpty);
    expect(File(contract).readAsBytesSync(), before[0]);
    expect(File(invoice).readAsBytesSync(), before[1]);
  });

  test(
    'an image becomes a page; a locked PDF opens with its password',
    () async {
      final photo = File('${dir.path}/receipt.jpg')
        ..writeAsBytesSync(img.encodeJpg(img.Image(width: 300, height: 400)));
      final run = await queue.start(
        'merge',
        input([photo.path, locked], passwords: {locked: 'dokulo'}),
      );
      final output = await run.result as OneFile;
      expect(output.path, '${outDir.path}/receipt – merged.pdf');
      final info = await PdfEngine.inspect(output.path);
      expect(info.pageCount, 2);
      expect(
        info.pages.first.width / info.pages.first.height,
        closeTo(.75, .01),
      );
      // Opened above without a password: the output is not encrypted.
    },
  );

  test(
    'a locked PDF without its password fails as locked, leaving nothing',
    () async {
      final run = await queue.start('merge', input([invoice, locked]));
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
    },
  );

  test('fewer than two files is refused', () async {
    final run = await queue.start('merge', input([invoice]));
    await expectLater(
      run.result,
      throwsA(
        isA<JobFailed>().having(
          (e) => e.message,
          'message',
          contains('2 to 500'),
        ),
      ),
    );
  });

  test('200 pages merge fast (target < 3 s on a mid Android)', () async {
    final watch = Stopwatch()..start();
    final run = await queue.start(
      'merge',
      input([long, long], ranges: {0: '1-100', 1: '101-200'}),
    );
    final output = await run.result as OneFile;
    watch.stop();
    expect((await PdfEngine.inspect(output.path)).pageCount, 200);
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
  });

  group('bookmarks (DK-1101)', () {
    /// An outline as (title, page) in reading order, children after their
    /// parent.
    List<(String, int?)> flat(List<OutlineEntry> entries) => [
      for (final e in entries) ...[(e.title, e.page), ...flat(e.children)],
    ];

    test('each file keeps its bookmarks, moved to its pages; a range keeps '
        'only those inside it; the file checks clean', () async {
      final own = flat(await PdfEngine.outline(contract));
      expect(own, isNotEmpty, reason: 'the contract has bookmarks per §');
      final run = await queue.start(
        'merge',
        input([contract, contract], ranges: {1: '2-3'}),
      );
      final output = await run.result as OneFile;
      final merged = flat(await PdfEngine.outline(output.path));
      expect(merged, [
        ...own,
        // The second copy gave pages 2-3 (1, 2), now at output pages 3, 4.
        for (final (title, page) in own)
          if (page != null && page >= 1) (title, page - 1 + 3),
      ]);
      expect(await pool.run(Lane.qpdf, _check, output.path).result, isEmpty);
    });

    test('Keep bookmarks off: none', () async {
      final run = await queue.start(
        'merge',
        MergeInput(
          files: [contract, invoice],
          outputDir: outDir.path,
          suffix: ' – merged',
          keepBookmarks: false,
        ),
      );
      final output = await run.result as OneFile;
      expect(await PdfEngine.outline(output.path), isEmpty);
    });

    test('rangePages reads qpdf ranges, or says it can\'t', () {
      expect(PdfOutline.rangePages(null, 3), [0, 1, 2]);
      expect(PdfOutline.rangePages('3,1', 3), [2, 0]);
      expect(PdfOutline.rangePages('2-z', 4), [1, 2, 3]);
      expect(PdfOutline.rangePages('3-1', 3), [2, 1, 0]);
      expect(PdfOutline.rangePages('r1', 3), isNull);
    });
  });
}
