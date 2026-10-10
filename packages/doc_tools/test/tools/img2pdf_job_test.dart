import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:qpdf_ffi/qpdf_ffi.dart';
import 'package:test/test.dart';

List<String> _check(String path, JobContext context) =>
    QpdfService.run(() => Qpdf.check(path));

/// A photo-like JPEG: noise, so it is as large as a real one.
Uint8List photo(int width, int height, {int seed = 1}) {
  final r = Random(seed);
  final im = img.Image(width: width, height: height);
  for (final p in im) {
    p
      ..r = r.nextInt(256)
      ..g = r.nextInt(256)
      ..b = r.nextInt(256);
  }
  return img.encodeJpg(im, quality: 85);
}

void main() {
  setUpAll(pdfrxInitialize);
  late Directory dir, outDir;
  late IsolatePool pool;
  late DokuloDatabase db;
  late JobQueue queue;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dk_img2pdf_job_');
    outDir = Directory('${dir.path}/out')..createSync();
    pool = IsolatePool(tempRoot: Directory('${dir.path}/jobs')..createSync());
    db = DokuloDatabase.memory();
    queue = JobQueue(pool, db, ToolRegistry.app());
  });

  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Img2PdfInput input(
    List<String> files, {
    bool onePerImage = false,
    ImagePageSize size = ImagePageSize.fit,
  }) => Img2PdfInput(
    files: files,
    outputDir: outDir.path,
    suffix: ' – converted',
    size: size,
    onePerImage: onePerImage,
  );

  String write(String name, Uint8List bytes) =>
      (File('${dir.path}/$name')..writeAsBytesSync(bytes)).path;

  test(
    'one PDF named after the first image, pages in order, per-image progress, '
    'checks clean, originals untouched',
    () async {
      final a = write('IMG_0001.jpg', photo(300, 400));
      final b = write(
        'Receipt.png',
        img.encodePng(img.Image(width: 500, height: 200)),
      );
      final originals = [File(a).readAsBytesSync(), File(b).readAsBytesSync()];
      final run = await queue.start('img2pdf', input([a, b, a]));
      final progress = run.progress.toList();
      final output = await run.result as OneFile;

      expect(output.path, '${outDir.path}/IMG_0001 – converted.pdf');
      final pages = (await PdfEngine.inspect(output.path)).pages;
      expect([for (final p in pages) p.width < p.height], [true, false, true]);
      expect(await pool.run(Lane.qpdf, _check, output.path).result, isEmpty);
      expect([File(a).readAsBytesSync(), File(b).readAsBytesSync()], originals);
      final events = await progress;
      expect(events.map((p) => p.pageIndex), [0, 1, 2]);
      expect(events.every((p) => p.pageCount == 3), isTrue);
    },
  );

  test('One per image: a PDF each, "(2)" for a repeated name', () async {
    final a = write('scan.jpg', photo(100, 100));
    final run = await queue.start(
      'img2pdf',
      input([a, a], onePerImage: true, size: ImagePageSize.a4),
    );
    final output = await run.result as ManyFiles;
    expect(output.paths.map((p) => p.split('/').last), [
      'scan – converted.pdf',
      'scan – converted (2).pdf',
    ]);
    for (final p in output.paths) {
      expect((await PdfEngine.inspect(p)).pageCount, 1);
    }
  });

  // The spec's 10 s is a phone budget (DK-0432), checked on a device
  // (#1331); on this desktop, shared with the other agents' builds, it
  // measured 11-13 s under load.
  // ponytail: a 2x margin here catches a real regression, not the load.
  test('50 photos (12 MP) in under 20 s on the desktop', () async {
    final bytes = photo(4000, 3000);
    final files = [for (var i = 0; i < 50; i++) write('p$i.jpg', bytes)];
    final clock = Stopwatch()..start();
    final output =
        await (await queue.start('img2pdf', input(files))).result as OneFile;
    expect(clock.elapsed, lessThan(const Duration(seconds: 20)));
    expect((await PdfEngine.inspect(output.path)).pageCount, 50);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('cancel leaves no files and the originals untouched', () async {
    final a = write('a.jpg', photo(2000, 1500));
    final original = File(a).readAsBytesSync();
    final run = await queue.start('img2pdf', input(List.filled(40, a)));
    await run.progress.first;
    run.cancel();
    await expectLater(run.result, throwsA(isA<JobCancelled>()));
    expect(outDir.listSync(), isEmpty);
    expect(File(a).readAsBytesSync(), original);
  });

  test('a file that is not an image fails as "damaged" on its page, '
      'and leaves nothing', () async {
    final a = write('a.jpg', photo(100, 100));
    final bad = write('notes.heic', Uint8List.fromList(List.filled(64, 7)));
    final run = await queue.start('img2pdf', input([a, bad]));
    await expectLater(
      run.result,
      throwsA(
        isA<JobFailed>().having(
          (e) => e.message,
          'message',
          allOf(contains('DocError(damaged'), contains('page 1')),
        ),
      ),
    );
    expect(outDir.listSync(), isEmpty);
  });

  test('Clean up like a scan crops to the page in the photo', () async {
    // A white portrait sheet on a dark, landscape desk.
    final desk = img.Image(width: 1200, height: 900)
      ..clear(img.ColorRgb8(40, 40, 40));
    img.fillRect(
      desk,
      x1: 400,
      y1: 150,
      x2: 800,
      y2: 710,
      color: img.ColorRgb8(245, 245, 240),
    );
    final a = write('desk.jpg', img.encodeJpg(desk));
    final run = await queue.start(
      'img2pdf',
      Img2PdfInput(
        files: [a],
        outputDir: outDir.path,
        suffix: ' – converted',
        cleanUp: true,
      ),
    );
    final output = await run.result as OneFile;
    final page = (await PdfEngine.inspect(output.path)).pages.single;
    // Fit image: the page has the sheet's proportions (400 × 560).
    expect(page.width / page.height, closeTo(400 / 560, 0.05));
  });

  test('Skip this page (DK-1086): a skipped image is left out', () async {
    final a = write('a.jpg', photo(100, 120));
    final run = await queue.start(
      'img2pdf',
      Img2PdfInput(
        files: [a, a, a],
        outputDir: outDir.path,
        suffix: '',
        skipPages: const [1],
      ),
    );
    final output = await run.result as OneFile;
    expect((await PdfEngine.inspect(output.path)).pageCount, 2);
  });

  test("in a chain it takes the previous step's files", () {
    final chained = const Img2PdfJob().chain(
      const ManyFiles(['a.jpg', 'b.png']),
      {'outputDir': '/out', 'suffix': ' – converted', 'size': 'letter'},
    );
    expect(chained.files, ['a.jpg', 'b.png']);
    expect(chained.size, ImagePageSize.letter);
  });
}
