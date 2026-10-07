import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:test/test.dart';

void _spin(int ms) {
  final clock = Stopwatch()..start();
  while (clock.elapsedMilliseconds < ms) {}
}

/// A page-based fake tool: "processes" `pages` pages, then writes `out`.
class _Pages extends ToolJob<Map<String, Object?>> {
  const _Pages();

  @override
  String get id => 'pages';

  @override
  Lane get lane => Lane.pdfium;

  @override
  Map<String, Object?> encode(Map<String, Object?> input) => input;

  @override
  Map<String, Object?> decode(Map<String, Object?> json) => json;

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
    final pages = input['pages']! as int;
    for (var page = 0; page < pages; page++) {
      context.report(JobProgress('working', pageIndex: page, pageCount: pages));
      _spin(input['msPerPage'] as int? ?? 20);
      await context.checkCancelled();
    }
    final out = File(input['out']! as String)
      ..writeAsStringSync('$pages pages');
    return OneFile(out.path);
  }
}

/// Reads a file (the previous step's output) and shouts its text.
class _Shout extends ToolJob<String> {
  const _Shout();

  @override
  String get id => 'shout';

  @override
  Lane get lane => Lane.qpdf;

  @override
  Map<String, Object?> encode(String input) => {'path': input};

  @override
  String decode(Map<String, Object?> json) => json['path']! as String;

  @override
  String chain(JobOutput previous, Map<String, Object?> options) =>
      (previous as OneFile).path;

  @override
  Future<JobOutput> run(
    String input,
    ToolJobContext context,
  ) async => TextOutput(
    '${File(input).readAsStringSync().toUpperCase()}${'!' * (context.isCancelled ? 0 : 1)}',
  );
}

class _Broken extends ToolJob<int> {
  const _Broken();

  @override
  String get id => 'broken';

  @override
  Lane get lane => Lane.opencv;

  @override
  Map<String, Object?> encode(int input) => {'n': input};

  @override
  int decode(Map<String, Object?> json) => json['n']! as int;

  @override
  int chain(JobOutput previous, Map<String, Object?> options) => 0;

  @override
  Future<JobOutput> run(int input, ToolJobContext context) =>
      throw StateError('damaged xref');
}

void main() {
  late Directory dir;
  late IsolatePool pool;
  late DokuloDatabase db;
  late JobQueue queue;
  final started = <String>[], finished = <String>[], failed = <String>[];

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dk_queue_test_');
    pool = IsolatePool(tempRoot: Directory('${dir.path}/tmp')..createSync());
    db = DokuloDatabase.memory();
    started.clear();
    finished.clear();
    failed.clear();
    queue = JobQueue(
      pool,
      db,
      ToolRegistry([const _Pages(), const _Shout(), const _Broken()]),
      hooks: JobHooks(
        onStarted: (run) => started.add(run.toolId),
        onFinished: (run, _) => finished.add(run.toolId),
        onFailed: (run, _) => failed.add(run.toolId),
      ),
    );
  });

  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Map<String, Object?> pages(int n, {int msPerPage = 20}) => {
    'pages': n,
    'out': '${dir.path}/out.txt',
    'msPerPage': msPerPage,
  };

  test('a job reports every page with time left, and its output', () async {
    final run = await queue.start('pages', pages(5));
    final progress = run.progress.toList();
    expect(queue.running, [run]);
    expect(
      await db.select(db.jobs).get(),
      hasLength(1),
      reason: 'the running job has a row',
    );

    final output = await run.result as OneFile;
    expect(File(output.path).readAsStringSync(), '5 pages');
    final events = await progress;
    expect(events.map((p) => p.pageIndex), [
      0,
      1,
      2,
      3,
      4,
    ], reason: 'at least once per page');
    expect(events.last.etaSeconds, 0);
    expect(events.last.fraction, 1.0);
    expect(
      [started, finished, failed],
      [
        ['pages'],
        ['pages'],
        isEmpty,
      ],
    );
    expect(queue.running, isEmpty);
    expect(
      await db.select(db.jobs).get(),
      isEmpty,
      reason: 'the row goes with the job',
    );
    expect(
      await db.lastUsedTool().getSingle(),
      'pages',
      reason: 'tool usage (DK-0022)',
    );
  });

  test('a failing job calls onFailed, leaves no row and no usage', () async {
    final run = await queue.start('broken', 1);
    await expectLater(
      run.result,
      throwsA(
        isA<JobFailed>().having(
          (e) => e.message,
          'message',
          contains('damaged xref'),
        ),
      ),
    );
    expect(failed, ['broken']);
    expect(await db.select(db.jobs).get(), isEmpty);
    expect(await db.lastUsedTool().getSingleOrNull(), isNull);
  });

  test(
    'a cancelled job is neither finished nor failed, and leaves no row',
    () async {
      final run = await queue.start('pages', pages(100, msPerPage: 30));
      await run.progress.first;
      run.cancel();
      await expectLater(run.result, throwsA(isA<JobCancelled>()));
      expect([...finished, ...failed], isEmpty);
      expect(await db.select(db.jobs).get(), isEmpty);
      expect(
        File('${dir.path}/out.txt').existsSync(),
        isFalse,
        reason: 'no partial output',
      );
    },
  );

  test('a job the OS killed is found on the next launch and can be resumed', () async {
    // What a killed launch leaves behind: a row and nothing else.
    await db
        .into(db.jobs)
        .insert(
          JobsCompanion.insert(
            toolId: 'pages',
            input:
                '{"pages":2,"out":"${dir.path.replaceAll(r'\', r'\\')}/out.txt"}',
            startedAt: DateTime(2026, 10, 7),
          ),
        );
    final left = await queue.unfinished();
    expect(left.single.toolId, 'pages');
    expect(left.single.input['pages'], 2);

    final run = await queue.resume(left.single);
    expect(
      await queue.unfinished(),
      isEmpty,
      reason: 'a running job is not unfinished',
    );
    expect(
      File((await run.result as OneFile).path).readAsStringSync(),
      '2 pages',
    );
    expect(await db.select(db.jobs).get(), isEmpty);
  });

  test('forget drops an unfinished job', () async {
    await db
        .into(db.jobs)
        .insert(
          JobsCompanion.insert(
            toolId: 'broken',
            input: '{"n":1}',
            startedAt: DateTime(2026, 10, 7),
          ),
        );
    await queue.forget((await queue.unfinished()).single);
    expect(await queue.unfinished(), isEmpty);
  });

  test(
    'a chain feeds each output into the next step, from JSON steps',
    () async {
      final steps = [
        {'tool': 'pages', 'options': <String, Object?>{}},
        {'tool': 'shout'},
      ].map(ChainStep.fromJson).toList();
      expect(steps.map((s) => s.toJson()['tool']), ['pages', 'shout']);
      final output = await queue.runChain(steps, pages(3)) as TextOutput;
      expect(output.text, '3 PAGES!');
      expect(finished, ['pages', 'shout']);
    },
  );

  test('outputs survive a JSON round trip', () {
    for (final output in const [
      OneFile('/a.pdf'),
      ManyFiles(['/a.pdf', '/b.pdf']),
      TextOutput('Hallo'),
    ]) {
      expect(JobOutput.fromJson(output.toJson()).toJson(), output.toJson());
    }
    expect(() => JobOutput.fromJson({'pages': 2}), throwsFormatException);
  });

  test('an undo snapshot puts the original back', () async {
    final original = File('${dir.path}/letter.pdf')..writeAsStringSync('v1');
    final snapshot = await UndoSnapshot.take(
      original.path,
      Directory('${dir.path}/tmp'),
    );
    original.writeAsStringSync('v2 (replaced)');
    await snapshot.restore();
    expect(original.readAsStringSync(), 'v1');
    await snapshot.discard();
    expect(File(snapshot.copy).existsSync(), isFalse);
  });
}
