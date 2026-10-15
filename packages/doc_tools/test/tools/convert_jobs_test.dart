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

/// Convert to PDF/A (DK-0450), PDF to text (DK-0456).
void main() {
  setUpAll(pdfrxInitialize);
  late Directory dir, outDir;
  late IsolatePool pool;
  late DokuloDatabase db;
  late JobQueue queue;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dk_convert_jobs_');
    outDir = Directory('${dir.path}/out')..createSync();
    pool = IsolatePool(tempRoot: Directory('${dir.path}/jobs')..createSync());
    db = DokuloDatabase.memory();
    queue = JobQueue(pool, db, ToolRegistry.app());
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  final contract = fixture('Mietvertrag Musterstraße 12.pdf');
  final invoice = fixture('Invoice INV-2026-014.pdf');
  final locked = fixture('encrypted-aes256.pdf'); // password "dokulo"

  test('PDF/A: a new file per input with the PDF/A identification, '
      'unencrypted, opens and checks clean; originals untouched', () async {
    final before = File(contract).readAsBytesSync();
    final input = PdfaInput(
      files: [contract, locked],
      outputDir: outDir.path,
      suffix: ' – PDF-A',
      passwords: {locked: 'dokulo'},
    );
    final job = ToolRegistry.app()['pdfa'];
    expect(job.encode(job.decode(job.encode(input))), job.encode(input));
    expect(job.encode(input).keys, isNot(contains('passwords')));

    final out = await (await queue.start('pdfa', input)).result as ManyFiles;
    expect(out.paths, [
      '${outDir.path}/Mietvertrag Musterstraße 12 – PDF-A.pdf',
      '${outDir.path}/encrypted-aes256 – PDF-A.pdf',
    ]);
    for (final p in out.paths) {
      expect(
        String.fromCharCodes(File(p).readAsBytesSync()),
        contains('pdfaid'),
      );
      expect((await PdfEngine.inspect(p)).pageCount, greaterThan(0));
      expect(await pool.run(Lane.qpdf, _check, p).result, isEmpty);
    }
    expect(File(contract).readAsBytesSync(), before);
  });

  test(
    'PDF to text: Markdown with headings and page markers, or plain',
    () async {
      final md =
          await (await queue.start(
                'text',
                TextInput(
                  file: contract,
                  outputDir: outDir.path,
                  pageMarker: 'Seite {n}',
                ),
              )).result
              as OneFile;
      expect(md.path, '${outDir.path}/Mietvertrag Musterstraße 12.md');
      final text = File(md.path).readAsStringSync();
      expect(text, startsWith('Seite 1'));
      expect(text, contains(RegExp(r'^#{1,3} ', multiLine: true)));
      expect(text, contains('Seite 2'));

      final plain =
          await (await queue.start(
                'text',
                TextInput(
                  file: invoice,
                  outputDir: outDir.path,
                  markdown: false,
                  pageMarker: null,
                ),
              )).result
              as OneFile;
      expect(plain.path, '${outDir.path}/Invoice INV-2026-014.txt');
      final p = File(plain.path).readAsStringSync();
      expect(p, isNot(contains('#')));
      expect(p, contains('INV-2026-014'));
    },
  );

  test('renderText: lists, numbered items and tables in Markdown', () {
    final md = TextJob.renderText([
      const Block(BlockKind.heading, 0, 'Titel', level: 1),
      const Block(BlockKind.listItem, 0, '• eins'),
      const Block(BlockKind.listItem, 0, '2. zwei'),
      const Block(
        BlockKind.table,
        0,
        'A\tB',
        rows: [
          ['A', 'B'],
          ['1', '2|3'],
        ],
      ),
    ], markdown: true);
    expect(
      md,
      '# Titel\n\n- eins\n\n2. zwei\n\n| A | B |\n| --- | --- |\n'
      r'| 1 | 2\|3 |'
      '\n',
    );
  });
}
