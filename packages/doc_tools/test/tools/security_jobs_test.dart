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

List<String> _check((String, String?) job, JobContext context) =>
    QpdfService.run(() => Qpdf.check(job.$1, password: job.$2));

/// Add password (DK-0498), Remove password (DK-0504), Repair PDF (DK-0468).
void main() {
  setUpAll(pdfrxInitialize);
  late Directory dir, outDir;
  late IsolatePool pool;
  late DokuloDatabase db;
  late JobQueue queue;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dk_security_jobs_');
    outDir = Directory('${dir.path}/out')..createSync();
    pool = IsolatePool(tempRoot: Directory('${dir.path}/jobs')..createSync());
    db = DokuloDatabase.memory();
    queue = JobQueue(pool, db, ToolRegistry.app());
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  final invoice = fixture('Invoice INV-2026-014.pdf');
  final locked = fixture('encrypted-aes256.pdf'); // password "dokulo"
  final damaged = fixture('damaged-xref.pdf');

  Future<void> checks(String path, {String? password}) async => expect(
    await pool.run(Lane.qpdf, _check, (path, password)).result,
    isEmpty,
  );

  Matcher failsAs(String what) => throwsA(
    isA<JobFailed>().having((e) => e.message, 'message', contains(what)),
  );

  test('Add password: AES-256 that opens only with it; the password is '
      'never stored; the original untouched', () async {
    final before = File(invoice).readAsBytesSync();
    final input = ProtectInput(
      files: [invoice],
      outputDir: outDir.path,
      suffix: ' – protected',
      password: 'sommer 2026',
      copying: false,
    );
    expect(
      ToolRegistry.app()['protect'].encode(input).toString(),
      isNot(contains('sommer')),
    );
    final out = await (await queue.start('protect', input)).result as OneFile;
    expect(out.path, '${outDir.path}/Invoice INV-2026-014 – protected.pdf');
    await expectLater(
      PdfEngine.inspect(out.path),
      throwsA(
        isA<DocError>().having((e) => e.kind, 'kind', DocErrorKind.locked),
      ),
    );
    expect(
      (await PdfEngine.inspect(out.path, password: 'sommer 2026')).pageCount,
      1,
    );
    await checks(out.path, password: 'sommer 2026');
    expect(File(invoice).readAsBytesSync(), before);
  });

  test(
    'a resumed Add password (no password stored) fails, leaving nothing',
    () async {
      final job = ToolRegistry.app()['protect'];
      final resumed = job.decode(
        job.encode(
          ProtectInput(
            files: [invoice],
            outputDir: outDir.path,
            suffix: ' – protected',
            password: 'x',
          ),
        ),
      );
      await expectLater(
        (await queue.start('protect', resumed)).result,
        failsAs('no password'),
      );
      expect(outDir.listSync(), isEmpty);
    },
  );

  test('Remove password: the right one gives an open copy; a wrong one '
      'fails as locked; a file without one says so', () async {
    UnlockInput input(String file, String password) => UnlockInput(
      file: file,
      outputDir: outDir.path,
      suffix: ' – unlocked',
      password: password,
    );
    final out =
        await (await queue.start('unlock', input(locked, 'dokulo'))).result
            as OneFile;
    expect(out.path, '${outDir.path}/encrypted-aes256 – unlocked.pdf');
    expect((await PdfEngine.inspect(out.path)).pageCount, 1);
    await checks(out.path);
    File(out.path).deleteSync();

    await expectLater(
      (await queue.start('unlock', input(locked, 'falsch'))).result,
      failsAs('DocError(locked'),
    );
    await expectLater(
      (await queue.start('unlock', input(invoice, ''))).result,
      failsAs('NotEncrypted'),
    );
    expect(outDir.listSync(), isEmpty);
  });

  test('Repair: a broken xref table is rebuilt into a file that opens and '
      'checks clean; the original untouched', () async {
    final before = File(damaged).readAsBytesSync();
    final out =
        await (await queue.start(
              'repair',
              RepairInput(
                file: damaged,
                outputDir: outDir.path,
                suffix: ' – repaired',
              ),
            )).result
            as OneFile;
    expect(out.path, '${outDir.path}/damaged-xref – repaired.pdf');
    expect((await PdfEngine.inspect(out.path)).pageCount, 1);
    await checks(out.path);
    expect(File(damaged).readAsBytesSync(), before);
  });

  test('Repair: not a PDF at all is too damaged, leaving nothing', () async {
    final junk = File('${dir.path}/junk.pdf')..writeAsStringSync('no pdf');
    await expectLater(
      (await queue.start(
        'repair',
        RepairInput(file: junk.path, outputDir: outDir.path, suffix: ' – r'),
      )).result,
      failsAs('DocError(damaged'),
    );
    expect(outDir.listSync(), isEmpty);
  });
}
