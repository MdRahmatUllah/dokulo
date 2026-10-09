import 'dart:convert';
import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

/// The shared sample corpus (DK-0023), from the repo root.
String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

const mb = 1000 * 1000;

Preflight on(DeviceCapabilities device) => Preflight(() async => device);

CompressInput compress(String file, {String? password}) => CompressInput(
  files: [file],
  outputDir: Directory.systemTemp.path,
  suffix: ' – compressed',
  password: password,
);

Future<DocError> failure(Future<void> Function() body) async {
  try {
    await body();
  } on DocError catch (e) {
    return e;
  }
  fail('it passed');
}

void main() {
  setUpAll(pdfrxInitialize);
  const tool = CompressJob();
  final long = fixture('long-300-pages.pdf');

  test('not enough storage: fails before the job, with the bytes needed '
      '(DK-0020)', () async {
    final size = File(long).lengthSync();
    final e = await failure(
      () =>
          on(const DeviceCapabilities(freeStorage: 1))
              .check(tool, compress(long)),
    );
    expect(e.kind, DocErrorKind.notEnoughStorage);
    expect(e.bytes, size * tool.spaceFactor);
  });

  test('too large for the free memory: a 300-page A4 file at 200 dpi '
      'against 20 MB free (DK-0020, DK-0613)', () async {
    final e = await failure(
      () =>
          on(const DeviceCapabilities(availableRam: 20 * mb))
              .check(tool, compress(long)),
    );
    expect(e.kind, DocErrorKind.tooLarge);
  });

  test('enough of both, or a phone that won\'t say: it passes', () async {
    await on(
      const DeviceCapabilities(
        freeStorage: 10000 * mb,
        availableRam: 2000 * mb,
      ),
    ).check(tool, compress(long));
    await on(const DeviceCapabilities()).check(tool, compress(long));
  });

  test('a locked input fails as locked without its password, and passes '
      'with it', () async {
    final locked = fixture('encrypted-aes256.pdf');
    final e = await failure(
      () => on(const DeviceCapabilities()).check(tool, compress(locked)),
    );
    expect(e.kind, DocErrorKind.locked);
    await on(const DeviceCapabilities())
        .check(tool, compress(locked, password: 'dokulo'));
  });

  test('the queue starts nothing that fails its preflight, and writes no '
      'jobs row', () async {
    final dir = await Directory.systemTemp.createTemp('dk_preflight_');
    addTearDown(() => dir.delete(recursive: true));
    final db = DokuloDatabase.memory();
    addTearDown(db.close);
    final queue = JobQueue(
      IsolatePool(tempRoot: dir),
      db,
      ToolRegistry.app(),
      preflight: on(const DeviceCapabilities(freeStorage: 1)),
    );
    final e = await failure(() => queue.start('compress', compress(long)));
    expect(e.kind, DocErrorKind.notEnoughStorage);
    expect(queue.running, isEmpty);
    expect(await db.select(db.jobs).get(), isEmpty);
  });

  test('a killed job whose preflight now fails keeps its row and is '
      "reported as couldn't finish, not resumed", () async {
    final dir = await Directory.systemTemp.createTemp('dk_preflight_');
    addTearDown(() => dir.delete(recursive: true));
    final db = DokuloDatabase.memory();
    addTearDown(db.close);
    // The job's row as the app left it when it was killed.
    await db
        .into(db.jobs)
        .insert(
          JobsCompanion.insert(
            toolId: 'compress',
            input: jsonEncode(tool.encode(compress(long))),
            startedAt: DateTime(2026),
          ),
        );
    final queue = JobQueue(
      IsolatePool(tempRoot: dir),
      db,
      ToolRegistry.app(),
      preflight: on(const DeviceCapabilities(freeStorage: 1)),
    );
    final job = (await queue.unfinished()).single;
    await expectLater(queue.resume(job), throwsA(isA<DocError>()));
    expect(await db.select(db.jobs).get(), hasLength(1), reason: 'row kept');
  });
}
