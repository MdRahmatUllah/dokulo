import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:qpdf_ffi/qpdf_ffi.dart';
import 'package:test/test.dart';

/// The shared sample corpus (DK-0023), from the repo root.
String fixture(String name) => '../../test/fixtures/$name';

/// Mean absolute difference of two renders of page 0, per channel (0–255).
Future<double> difference(String a, String b) async {
  final x = await PdfEngine.render(a, 0, dpi: 50),
      y = await PdfEngine.render(b, 0, dpi: 50);
  expect((x.width, x.height), (y.width, y.height));
  var sum = 0;
  for (var i = 0; i < x.bgra.length; i++) {
    if (i % 4 != 3) sum += (x.bgra[i] - y.bgra[i]).abs();
  }
  return sum / (x.bgra.length * 3 / 4);
}

int qpdfInWorker((String, String) job, JobContext context) => QpdfService.run(
  () => Qpdf.run({
    'inputFile': job.$1,
    'outputFile': job.$2,
    'qdf': '',
    'objectStreams': 'disable',
  }).length,
);

int structureInWorker((String, String) job, JobContext context) =>
    QpdfService.run(
      () => Qpdf.run({
        'inputFile': job.$1,
        'outputFile': job.$2,
        'objectStreams': 'generate',
        'compressStreams': 'y',
        'recompressFlate': '',
        'compressionLevel': '9',
      }).length,
    );

void main() {
  setUpAll(pdfrxInitialize);
  late Directory out;
  late IsolatePool pool;
  late PdfCompress compressor;
  setUp(() async {
    out = await Directory.systemTemp.createTemp('dk_compress_test_');
    pool = IsolatePool(tempRoot: Directory('${out.path}/jobs')..createSync());
    compressor = PdfCompress(pool);
  });
  tearDown(() => out.delete(recursive: true));
  String outFile(String name) => '${out.path}/$name';

  final scan = fixture('scanned-letters-bundle.pdf');

  test('strong downsamples a scan: smaller, same pages, same look', () async {
    final pages = <int>[];
    final result = await compressor.compress(
      scan,
      outFile('a.pdf'),
      const CompressOptions(preset: CompressPreset.strong),
      onPage: (done, total) => pages.add(done),
    );
    expect(result.imagesRecompressed, 6, reason: 'one scanned image per page');
    expect(result.bytesAfter, lessThan(result.bytesBefore));
    expect(result.bytesAfter, File(outFile('a.pdf')).lengthSync());
    expect(result.level, (quality: 50, dpi: 72));
    expect((await PdfEngine.inspect(outFile('a.pdf'))).pageCount, 6);
    expect(pages, [1, 2, 3, 4, 5, 6], reason: 'progress per page');
    expect(
      await difference(scan, outFile('a.pdf')),
      lessThan(8),
      reason: 'the pages look the same',
    );
  });

  test('images already below the target are left alone', () async {
    // The sample scan is 110 dpi and tightly encoded: at 150 dpi there's
    // nothing to gain, and re-encoding would only lose quality.
    final result = await compressor.compress(
      scan,
      outFile('r.pdf'),
      const CompressOptions(),
    );
    expect(result.imagesRecompressed, 0);
    expect(await difference(scan, outFile('r.pdf')), lessThan(1));
  });

  test('strong is smaller than low', () async {
    final low = await compressor.compress(
      scan,
      outFile('low.pdf'),
      const CompressOptions(preset: CompressPreset.low),
    );
    final strong = await compressor.compress(
      scan,
      outFile('strong.pdf'),
      const CompressOptions(preset: CompressPreset.strong),
    );
    expect(strong.bytesAfter, lessThan(low.bytesAfter));
  });

  test('greyscale turns the images grey', () async {
    await compressor.compress(
      scan,
      outFile('grey.pdf'),
      const CompressOptions(greyscale: true),
    );
    final page = await PdfEngine.render(outFile('grey.pdf'), 0, dpi: 30);
    var colourful = 0;
    for (var i = 0; i < page.bgra.length; i += 4) {
      final (b, g, r) = (page.bgra[i], page.bgra[i + 1], page.bgra[i + 2]);
      if ((r - g).abs() > 12 || (g - b).abs() > 12) colourful++;
    }
    expect(colourful, lessThan(page.width * page.height ~/ 100));
  });

  test('metadata is removed only when asked', () async {
    final invoice = fixture('Invoice INV-2026-014.pdf');
    Future<String> plain(String name) async {
      await pool.run(Lane.qpdf, qpdfInWorker, (
        outFile(name),
        outFile('$name.qdf'),
      )).result;
      return File(outFile('$name.qdf')).readAsStringSync(encoding: latin1);
    }

    await compressor.compress(
      invoice,
      outFile('kept.pdf'),
      const CompressOptions(),
    );
    await compressor.compress(
      invoice,
      outFile('clean.pdf'),
      const CompressOptions(removeMetadata: true),
    );
    expect(await plain('kept.pdf'), contains('/Producer'));
    expect(await plain('clean.pdf'), isNot(contains('/Producer')));
  });

  test('a size target gets the best quality that fits', () async {
    final low = await compressor.compress(
      scan,
      outFile('l.pdf'),
      const CompressOptions(preset: CompressPreset.low),
    );
    final strong = await compressor.compress(
      scan,
      outFile('s.pdf'),
      const CompressOptions(preset: CompressPreset.strong),
    );
    final target = (low.bytesAfter + strong.bytesAfter) ~/ 2;
    final result = await compressor.compress(
      scan,
      outFile('t.pdf'),
      CompressOptions(preset: CompressPreset.low, targetBytes: target),
    );
    expect(result.targetMet, isTrue);
    expect(result.bytesAfter, lessThanOrEqualTo(target));
    expect(File(outFile('t.pdf')).lengthSync(), result.bytesAfter);
  });

  test('a target out of reach gives the smallest file and says so', () async {
    final result = await compressor.compress(
      scan,
      outFile('tiny.pdf'),
      const CompressOptions(targetBytes: 1000),
    );
    expect(result.targetMet, isFalse);
    expect(result.level, (quality: 40, dpi: 72));
    expect(File(outFile('tiny.pdf')).existsSync(), isTrue);
  });

  test('cancel stops at the next page and writes nothing', () async {
    var done = 0;
    await expectLater(
      compressor.compress(
        scan,
        outFile('c.pdf'),
        const CompressOptions(),
        onPage: (d, _) => done = d,
        isCancelled: () => done >= 1,
      ),
      throwsA(
        isA<DocError>().having((e) => e.kind, 'kind', DocErrorKind.cancelled),
      ),
    );
    expect(File(outFile('c.pdf')).existsSync(), isFalse);
  });

  test(
    'an image shared by 8 pages is never copied per page (DK-1068)',
    () async {
      // One noisy 150 dpi grey scan, written once and drawn on every page.
      final scan = img.Image(width: 1240, height: 1754, numChannels: 1);
      final random = Random(7);
      for (final px in scan) {
        px.r = 200 + random.nextInt(55);
      }
      final doc = pw.Document();
      final image = pw.MemoryImage(img.encodeJpg(scan, quality: 85));
      for (var p = 0; p < 8; p++) {
        doc.addPage(
          pw.Page(
            pageFormat: pdf.PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
          ),
        );
      }
      final shared = outFile('shared.pdf');
      await File(shared).writeAsBytes(await doc.save());

      for (final preset in CompressPreset.values) {
        final path = outFile('s_${preset.name}.pdf');
        final result = await compressor.compress(
          shared,
          path,
          CompressOptions(preset: preset),
        );
        expect(
          result.bytesAfter,
          lessThanOrEqualTo(result.bytesBefore),
          reason: preset.name,
        );
        expect(result.bytesAfter, File(path).lengthSync());
        expect((await PdfEngine.inspect(path)).pageCount, 8);
        await pool.run(Lane.qpdf, qpdfInWorker, (path, '$path.qdf')).result;
        final images = '/Subtype /Image'
            .allMatches(File('$path.qdf').readAsStringSync(encoding: latin1))
            .length;
        // Either one shared image kept, or 8 copies that together are smaller.
        expect(
          images == 1 || result.imagesRecompressed == 8,
          isTrue,
          reason: '${preset.name}: $images images',
        );
      }
    },
  );

  test("a file that can't get smaller is kept as it is (DK-1068)", () async {
    final invoice = fixture('Invoice INV-2026-014.pdf');
    final small = outFile('small.pdf');
    // qpdf's own structure pass first: nothing left for Compress to win.
    await pool.run(Lane.qpdf, structureInWorker, (invoice, small)).result;
    final result = await compressor.compress(
      small,
      outFile('k.pdf'),
      const CompressOptions(),
    );
    expect(result.bytesAfter, lessThanOrEqualTo(result.bytesBefore));
    expect(File(outFile('k.pdf')).lengthSync(), result.bytesAfter);
  });

  test('a PDF without images stays valid and unchanged in look', () async {
    final invoice = fixture('Invoice INV-2026-014.pdf');
    final result = await compressor.compress(
      invoice,
      outFile('i.pdf'),
      const CompressOptions(),
    );
    expect(result.imagesRecompressed, 0);
    expect(await difference(invoice, outFile('i.pdf')), lessThan(1));
  });
}
