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

/// Split (DK-0408), Extract pages (DK-0414), Rotate PDF (DK-0420).
void main() {
  setUpAll(pdfrxInitialize);
  late Directory dir, outDir;
  late IsolatePool pool;
  late DokuloDatabase db;
  late JobQueue queue;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dk_organize_jobs_');
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
  final long = fixture('long-300-pages.pdf'); // a bookmark every 25 pages
  final locked = fixture('encrypted-aes256.pdf'); // password "dokulo"

  Future<List<String>> texts(String path) => PdfEngine.pageTexts(path);
  Future<int> pages(String path) async =>
      (await PdfEngine.inspect(path)).pageCount;
  Future<void> checks(String path) async =>
      expect(await pool.run(Lane.qpdf, _check, path).result, isEmpty);

  group('split', () {
    SplitInput input(
      String file, {
      SplitMode mode = SplitMode.ranges,
      List<String> ranges = const [],
      int every = 2,
      String? password,
    }) => SplitInput(
      file: file,
      outputDir: outDir.path,
      suffix: ' – split',
      mode: mode,
      ranges: ranges,
      every: every,
      password: password,
    );

    test('its input survives JSON without the password', () {
      final job = ToolRegistry.app()['split'];
      final json = job.encode(
        input(long, mode: SplitMode.everyN, every: 5, password: 'x'),
      );
      expect(job.encode(job.decode(json)), json);
      expect(json.toString(), isNot(contains('password')));
    });

    test('by ranges: one part each, numbered, the pages in them; checks '
        'clean, original untouched', () async {
      final before = File(contract).readAsBytesSync();
      final run = await queue.start(
        'split',
        input(contract, ranges: ['1', '2-z']),
      );
      final out = await run.result as ManyFiles;
      expect(out.paths, [
        '${outDir.path}/Mietvertrag Musterstraße 12 – split 1.pdf',
        '${outDir.path}/Mietvertrag Musterstraße 12 – split 2.pdf',
      ]);
      final all = await texts(contract);
      expect(await texts(out.paths[0]), [all[0]]);
      expect(await texts(out.paths[1]), [all[1], all[2]]);
      for (final p in out.paths) {
        await checks(p);
      }
      expect(File(contract).readAsBytesSync(), before);
    });

    test('every N, each page, and at the bookmarks', () async {
      Future<List<int>> sizes(SplitInput i) async {
        final out = await (await queue.start('split', i)).result as ManyFiles;
        final n = [for (final p in out.paths) await pages(p)];
        for (final p in out.paths) {
          File(p).deleteSync();
        }
        return n;
      }

      expect(await sizes(input(contract, mode: SplitMode.everyN)), [2, 1]);
      expect(await sizes(input(contract, mode: SplitMode.eachPage)), [1, 1, 1]);
      final chapters = await sizes(input(long, mode: SplitMode.bookmarks));
      expect(chapters.fold(0, (a, b) => a + b), 300);
      expect(chapters.length, greaterThan(1));
    });

    test('100 pages into 10 files fast (target < 3 s)', () async {
      final watch = Stopwatch()..start();
      final run = await queue.start(
        'split',
        input(
          long,
          ranges: [for (var i = 0; i < 10; i++) '${i * 10 + 1}-${i * 10 + 10}'],
        ),
      );
      final out = await run.result as ManyFiles;
      watch.stop();
      expect(out.paths, hasLength(10));
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    });

    test('a locked PDF opens with its password; without, it fails as '
        'locked and leaves nothing', () async {
      final ok = await queue.start(
        'split',
        input(locked, mode: SplitMode.eachPage, password: 'dokulo'),
      );
      expect((await ok.result as ManyFiles).paths, hasLength(1));
      for (final f in outDir.listSync()) {
        f.deleteSync();
      }
      final run = await queue.start(
        'split',
        input(locked, mode: SplitMode.eachPage),
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
  });

  group('extract', () {
    ExtractInput input(String file, List<int> pages) => ExtractInput(
      file: file,
      pages: pages,
      outputDir: outDir.path,
      suffix: ' – extract',
    );

    test(
      'the pages in the given order; checks clean, original untouched',
      () async {
        final before = File(contract).readAsBytesSync();
        final run = await queue.start('extract', input(contract, [2, 0]));
        final out = await run.result as OneFile;
        expect(
          out.path,
          '${outDir.path}/Mietvertrag Musterstraße 12 – extract.pdf',
        );
        final all = await texts(contract);
        expect(await texts(out.path), [all[2], all[0]]);
        await checks(out.path);
        expect(File(contract).readAsBytesSync(), before);
        final json = ToolRegistry.app()['extract'].encode(
          input(contract, [2, 0]),
        );
        expect(
          ToolRegistry.app()['extract'].encode(
            ToolRegistry.app()['extract'].decode(json),
          ),
          json,
        );
      },
    );

    test('a page that does not exist is refused, leaving nothing', () async {
      final run = await queue.start('extract', input(contract, [3]));
      await expectLater(run.result, throwsA(isA<JobFailed>()));
      expect(outDir.listSync(), isEmpty);
    });
  });

  group('rotate', () {
    RotateInput input(String file, Map<int, int> turns) => RotateInput(
      file: file,
      turns: turns,
      outputDir: outDir.path,
      suffix: ' – rotated',
    );

    test(
      'the chosen pages turn, the others stay; text kept, checks clean',
      () async {
        final before = File(contract).readAsBytesSync();
        final run = await queue.start('rotate', input(contract, {0: 1, 2: -1}));
        final out = await run.result as OneFile;
        expect(
          out.path,
          '${outDir.path}/Mietvertrag Musterstraße 12 – rotated.pdf',
        );
        final info = await PdfEngine.inspect(out.path);
        expect([for (final p in info.pages) p.quarterTurns], [1, 0, 3]);
        // The same words per page; a turned page reads in another order.
        Set<String> words(String t) => t.split(RegExp(r'\s+')).toSet();
        expect(
          (await texts(out.path)).map(words).toList(),
          (await texts(contract)).map(words).toList(),
        );
        await checks(out.path);
        expect(File(contract).readAsBytesSync(), before);
        final json = ToolRegistry.app()['rotate'].encode(
          input(contract, {0: 1}),
        );
        expect(
          ToolRegistry.app()['rotate'].encode(
            ToolRegistry.app()['rotate'].decode(json),
          ),
          json,
        );
      },
    );
  });
}
