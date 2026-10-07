import 'dart:convert';
import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:drift/drift.dart' show Value;
import 'package:test/test.dart';

/// Copies `src` to `out`; `src` is its input file.
class _Copy extends ToolJob<Map<String, Object?>> {
  const _Copy();

  @override
  String get id => 'copy';

  @override
  Lane get lane => Lane.qpdf;

  @override
  Map<String, Object?> encode(Map<String, Object?> input) => input;

  @override
  Map<String, Object?> decode(Map<String, Object?> json) => json;

  @override
  List<String> inputFiles(Map<String, Object?> input) => [
    input['src']! as String,
  ];

  @override
  Map<String, Object?> chain(
    JobOutput previous,
    Map<String, Object?> options,
  ) => throw UnimplementedError();

  @override
  Future<JobOutput> run(
    Map<String, Object?> input,
    ToolJobContext context,
  ) async {
    final out = await File(input['src']! as String)
        .copy(input['out']! as String);
    return OneFile(out.path);
  }
}

void main() {
  late Directory root;
  late DokuloDatabase db;
  late FileStore files;
  late IsolatePool pool;
  late JobQueue queue;
  final tools = ToolRegistry(const [_Copy()]);
  final now = DateTime(2026, 10, 7, 12);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('dk_startup_');
    db = DokuloDatabase.memory();
    files = FileStore(
      userFolder: Directory('${root.path}/Dokulo'),
      workDirectory: Directory('${root.path}/work'),
    );
    pool = IsolatePool(tempRoot: Directory('${root.path}/jobs')..createSync());
    queue = JobQueue(pool, db, tools);
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  /// A jobs row as the queue leaves it when the OS kills the app mid-run.
  Future<void> killedJob(String toolId, Map<String, Object?> input) => db
      .into(db.jobs)
      .insert(
        JobsCompanion.insert(
          toolId: toolId,
          input: jsonEncode(input),
          startedAt: now,
        ),
      );

  Future<StartupReport> launch() => startupCleanup(
    db: db,
    files: files,
    queue: queue,
    tools: tools,
    jobTempRoot: Directory('${root.path}/jobs'),
    now: now,
  );

  test('killed mid-run: a clear state and no partial file; the job runs again', () async {
    final source = File('${root.path}/Rechnung.pdf')
      ..writeAsStringSync('%PDF original');
    // What the killed run left: a half-written output in temp, its scratch dir.
    final partial = await files.newTempFile('Rechnung – compressed.pdf');
    await partial.writeAsString('%PDF half');
    Directory('${root.path}/jobs/dk_job_abc').createSync();
    final keep = Directory('${root.path}/jobs/other')..createSync();
    await killedJob('copy', {'src': source.path, 'out': partial.path});

    final report = await launch();
    expect(Directory('${root.path}/jobs/dk_job_abc').existsSync(), isFalse);
    expect(keep.existsSync(), isTrue);
    expect(
      files.userFolder.existsSync(),
      isFalse,
      reason: 'nothing partial in the user folder',
    );
    expect(report.couldNotFinish, isEmpty);
    expect(report.resumed.single.toolId, 'copy');
    expect(await queue.unfinished(), isEmpty);
    expect(source.readAsStringSync(), '%PDF original');
    // The rerun writes a complete output from the start.
    final output = await report.resumed.single.result as OneFile;
    expect(File(output.path).readAsStringSync(), '%PDF original');
  });

  test('a resumed job finishes; its output is complete', () async {
    final source = File('${root.path}/Brief.pdf')
      ..writeAsStringSync('%PDF letter');
    await killedJob('copy', {
      'src': source.path,
      'out': '${root.path}/out.pdf',
    });
    final report = await launch();
    final output = await report.resumed.single.result;
    expect(File((output as OneFile).path).readAsStringSync(), '%PDF letter');
  });

  test(
    "input gone or tool gone: reported, not run, kept until the user acts",
    () async {
      await killedJob('copy', {
        'src': '${root.path}/deleted.pdf',
        'out': '${root.path}/x.pdf',
      });
      await killedJob('retired-tool', {'src': '${root.path}/y.pdf'});

      final report = await launch();

      expect(report.resumed, isEmpty);
      expect(report.couldNotFinish.map((j) => j.toolId), [
        'copy',
        'retired-tool',
      ]);
      expect(await queue.unfinished(), hasLength(2));
      await queue.forget(report.couldNotFinish.first);
      expect(await queue.unfinished(), hasLength(1));
    },
  );

  test(
    'Recently deleted: files past 30 days are deleted, newer ones stay',
    () async {
      Future<File> trashed(String name, int daysAgo) async {
        final file = File('${root.path}/$name')..writeAsStringSync('x');
        final id = await db
            .into(db.files)
            .insert(
              FilesCompanion.insert(
                path: file.path,
                name: name,
                size: 1,
                created: now,
                modified: now,
              ),
            );
        await db
            .into(db.trash)
            .insert(
              TrashCompanion.insert(
                fileId: Value(id),
                deletedAt: now.subtract(Duration(days: daysAgo)),
              ),
            );
        return file;
      }

      final old = await trashed('old.pdf', 31);
      final recent = await trashed('recent.pdf', 5);

      final report = await launch();

      expect(report.trashPurged, 1);
      expect(old.existsSync(), isFalse);
      expect(recent.existsSync(), isTrue);
      expect((await db.select(db.files).get()).map((f) => f.name), [
        'recent.pdf',
      ]);
      expect(await db.select(db.trash).get(), hasLength(1));
    },
  );
}
