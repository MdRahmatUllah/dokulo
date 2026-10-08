import 'dart:io';
import 'dart:math';

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

void _concat((List<String>, String) job, JobContext context) => QpdfService.run(
  () => Qpdf.run({
    'inputFile': job.$1.first,
    'outputFile': job.$2,
    'pages': [
      for (final f in job.$1) {'file': f},
    ],
  }),
);

/// SSIM of page 0 of two PDFs, on grey renders in 8×8 windows.
Future<double> ssim(String a, String b) async {
  final x = await PdfEngine.render(a, 0, dpi: 72),
      y = await PdfEngine.render(b, 0, dpi: 72);
  double grey(List<int> p, int i) =>
      0.299 * p[i + 2] + 0.587 * p[i + 1] + 0.114 * p[i];
  const c1 = 6.5025, c2 = 58.5225; // (0.01·255)², (0.03·255)²
  var sum = 0.0, windows = 0;
  for (var wy = 0; wy + 8 <= x.height; wy += 8) {
    for (var wx = 0; wx + 8 <= x.width; wx += 8) {
      var mx = 0.0, my = 0.0;
      final xs = <double>[], ys = <double>[];
      for (var j = 0; j < 8; j++) {
        for (var i = 0; i < 8; i++) {
          final k = ((wy + j) * x.width + wx + i) * 4;
          xs.add(grey(x.bgra, k));
          ys.add(grey(y.bgra, k));
        }
      }
      mx = xs.reduce((a, b) => a + b) / 64;
      my = ys.reduce((a, b) => a + b) / 64;
      var vx = 0.0, vy = 0.0, cov = 0.0;
      for (var n = 0; n < 64; n++) {
        vx += pow(xs[n] - mx, 2);
        vy += pow(ys[n] - my, 2);
        cov += (xs[n] - mx) * (ys[n] - my);
      }
      vx /= 63;
      vy /= 63;
      cov /= 63;
      sum +=
          ((2 * mx * my + c1) * (2 * cov + c2)) /
          ((mx * mx + my * my + c1) * (vx + vy + c2));
      windows++;
    }
  }
  return sum / windows;
}

void main() {
  setUpAll(pdfrxInitialize);
  late Directory dir, outDir;
  late IsolatePool pool;
  late DokuloDatabase db;
  late JobQueue queue;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dk_compress_job_');
    outDir = Directory('${dir.path}/out')..createSync();
    pool = IsolatePool(tempRoot: Directory('${dir.path}/jobs')..createSync());
    db = DokuloDatabase.memory();
    queue = JobQueue(pool, db, ToolRegistry.app());
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  final scan = fixture('scanned-letters-bundle.pdf');
  CompressInput input(
    List<String> files, {
    CompressPreset preset = CompressPreset.recommended,
    String? password,
  }) => CompressInput(
    files: files,
    outputDir: outDir.path,
    suffix: ' – compressed',
    preset: preset,
    password: password,
  );

  test(
    'compress is registered and its input survives JSON (the jobs table)',
    () {
      final job = ToolRegistry.app()['compress'];
      final json = job.encode(input([scan], preset: CompressPreset.strong));
      expect(job.encode(job.decode(json)), json);
      expect(job.inputFiles(job.decode(json)), [scan]);
      expect(
        job.encode(input([scan], password: 'geheim')),
        isNot(contains('password')),
        reason: 'never stored in the jobs table',
      );
    },
  );

  test('a scan: a new file named with the suffix, per-page progress, checks clean, original untouched', () async {
    final original = File(scan).readAsBytesSync();
    final run = await queue.start(
      'compress',
      input([scan], preset: CompressPreset.strong),
    );
    final progress = run.progress.toList();
    final output = await run.result as OneFile;

    expect(
      output.path,
      '${outDir.path}/scanned-letters-bundle – compressed.pdf',
    );
    expect(File(output.path).lengthSync(), lessThan(original.length));
    expect(
      (await PdfEngine.inspect(output.path)).pageCount,
      6,
      reason: 'opens in PDFium',
    );
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
    final events = await progress;
    expect(events.map((p) => p.pageIndex), [0, 1, 2, 3, 4, 5]);
    expect(events.every((p) => p.pageCount == 6), isTrue);
  });

  test('a batch: one output each, "(2)" for a repeated name, progress over all pages', () async {
    final invoice = fixture('Invoice INV-2026-014.pdf');
    final run = await queue.start('compress', input([scan, invoice, invoice]));
    final progress = run.progress.toList();
    final output = await run.result as ManyFiles;
    expect(output.paths.map((p) => p.split('/').last), [
      'scanned-letters-bundle – compressed.pdf',
      'Invoice INV-2026-014 – compressed.pdf',
      'Invoice INV-2026-014 – compressed (2).pdf',
    ]);
    expect((await progress).last.pageCount, 8);
  });

  test(
    'Recommended keeps SSIM ≥ 0.9; a 54-page scan takes under 20 s',
    () async {
      final long = '${dir.path}/54.pdf';
      await pool.run(Lane.qpdf, _concat, (List.filled(9, scan), long)).result;
      final clock = Stopwatch()..start();
      final output =
          await (await queue.start('compress', input([long]))).result
              as OneFile;
      expect(clock.elapsed, lessThan(const Duration(seconds: 20)));
      expect((await PdfEngine.inspect(output.path)).pageCount, 54);
      expect(await ssim(long, output.path), greaterThanOrEqualTo(0.9));
      // Strong changes pixels; it should still look like the page.
      final strong =
          await (await queue.start(
                'compress',
                input([scan], preset: CompressPreset.strong),
              )).result
              as OneFile;
      expect(await ssim(scan, strong.path), greaterThanOrEqualTo(0.6));
    },
  );

  test('cancel leaves no files and the original untouched', () async {
    final original = File(scan).readAsBytesSync();
    final run = await queue.start(
      'compress',
      input([scan, scan, scan], preset: CompressPreset.strong),
    );
    await run.progress.first;
    run.cancel();
    await expectLater(run.result, throwsA(isA<JobCancelled>()));
    expect(outDir.listSync(), isEmpty);
    expect(File(scan).readAsBytesSync(), original);
  });

  test('a wrong password fails as the catalogue\'s "locked"', () async {
    final run = await queue.start(
      'compress',
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

  test('in a chain it takes the previous step\'s files', () {
    final next = const CompressJob().chain(
      OneFile(scan),
      input([]).toJson()..remove('files'),
    );
    expect(next.files, [scan]);
    expect(next.preset, CompressPreset.recommended);
  });
}
