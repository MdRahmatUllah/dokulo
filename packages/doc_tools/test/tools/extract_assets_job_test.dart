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
    dir = Directory.systemTemp.createTempSync('dk_extractassets_job_');
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

  final scans = fixture('scanned-letters-bundle.pdf');
  final contract = fixture('Mietvertrag Musterstraße 12.pdf');

  ExtractAssetsInput input(
    String file, {
    bool images = true,
    bool text = false,
    int minPixels = 100,
  }) => ExtractAssetsInput(
    file: file,
    outputDir: outDir.path,
    suffix: ' – Bild',
    images: images,
    text: text,
    minPixels: minPixels,
  );

  test('the images of a scan bundle as files that decode; the input '
      'survives JSON; the original untouched', () async {
    final before = File(scans).readAsBytesSync();
    final job = ToolRegistry.app()['extractassets'];
    final json = job.encode(input(scans, text: true, minPixels: 500));
    expect(job.encode(job.decode(json)), json);

    final out =
        await (await queue.start('extractassets', input(scans))).result
            as ManyFiles;
    expect(out.paths, isNotEmpty);
    expect(
      out.paths.first,
      startsWith('${outDir.path}/scanned-letters-bundle – Bild 01.'),
    );
    for (final p in out.paths) {
      expect(img.decodeImage(File(p).readAsBytesSync()), isNotNull, reason: p);
    }
    expect(File(scans).readAsBytesSync(), before);
  });

  test('text only: one .txt with every page; a PDF without images gives '
      'none', () async {
    final out =
        await (await queue.start(
              'extractassets',
              input(contract, text: true),
            )).result
            as ManyFiles;
    final txt = out.paths.where((p) => p.endsWith('.txt')).single;
    expect(txt, '${outDir.path}/Mietvertrag Musterstraße 12.txt');
    final pages = await PdfEngine.pageTexts(contract);
    final text = File(txt).readAsStringSync();
    for (final page in pages) {
      expect(text, contains(page.trim().split('\n').first.trim()));
    }
    expect(out.paths.where((p) => !p.endsWith('.txt')), isEmpty);
  });
}
