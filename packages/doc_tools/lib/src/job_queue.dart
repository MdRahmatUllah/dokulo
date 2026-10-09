import 'dart:async';
import 'dart:convert';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';

import 'preflight.dart';
import 'registry.dart';
import 'tool_job.dart';

/// What the job queue tells the app: notifications (DK-0588, DK-0589), and
/// keeping the app alive in the background (iOS background task, Android
/// foreground service, DK-0593) while [JobQueue.running] is not empty.
class JobHooks {
  const JobHooks({this.onStarted, this.onFinished, this.onFailed});

  final void Function(ToolRun run)? onStarted;
  final void Function(ToolRun run, JobOutput output)? onFinished;

  /// [error] is usually a [JobFailed]. A cancel is not a failure: it calls
  /// neither hook.
  final void Function(ToolRun run, Object error)? onFailed;
}

/// A job the queue is running.
class ToolRun {
  ToolRun._(this.id, this.toolId, this._job);

  /// Its row in the jobs table.
  final int id;
  final String toolId;
  final Job<JobOutput> _job;
  late final Stream<JobProgress> progress;
  late final Future<JobOutput> result;

  void cancel() => _job.cancel();
}

/// A job from an earlier launch that never ended: the OS killed the app.
class UnfinishedJob {
  UnfinishedJob._(this.id, this.toolId, this.input, this.startedAt);

  final int id;
  final String toolId;
  final Map<String, Object?> input;
  final DateTime startedAt;
}

/// One step of a chain, stored as JSON (`workflows.steps`).
class ChainStep {
  const ChainStep(this.toolId, [this.options = const {}]);

  factory ChainStep.fromJson(Map<String, Object?> json) => ChainStep(
    json['tool']! as String,
    (json['options'] as Map? ?? const {}).cast<String, Object?>(),
  );

  final String toolId;
  final Map<String, Object?> options;

  Map<String, Object?> toJson() => {'tool': toolId, 'options': options};
}

/// Runs ToolJobs on the [IsolatePool] and remembers the running ones in the
/// jobs table, so a job the OS kills is found on the next launch
/// ([unfinished]). One queue per app.
class JobQueue {
  JobQueue(
    this._pool,
    this._db,
    this._tools, {
    this.hooks = const JobHooks(),
    this.preflight,
  });

  final IsolatePool _pool;
  final DokuloDatabase _db;
  final ToolRegistry _tools;
  final JobHooks hooks;

  /// The checks before a job starts (DK-0020); none in tests that don't
  /// give one.
  final Preflight? preflight;
  final _running = <int, ToolRun>{};

  Iterable<ToolRun> get running => _running.values;

  /// Starts tool [toolId] on [input].
  Future<ToolRun> start(String toolId, Object? input) async {
    final tool = _tools[toolId];
    // Known to fail (no space, too large, locked)? Then it never starts.
    await preflight?.check(tool, input);
    return _start(toolId, input);
  }

  Future<ToolRun> _start(String toolId, Object? input) async {
    final tool = _tools[toolId];
    final id = await _db
        .into(_db.jobs)
        .insert(
          JobsCompanion.insert(
            toolId: toolId,
            input: jsonEncode(tool.encode(input)),
            startedAt: DateTime.now(),
          ),
        );
    final job = _pool.run(tool.lane, _runTool, (tool, input));
    final clock = Stopwatch()..start();
    final run = ToolRun._(id, toolId, job)
      ..progress = job.progress
          .where((e) => e is JobProgress)
          .map((e) => _withEta(e as JobProgress, clock.elapsed));
    run.result = _finish(run, job.result);
    _running[id] = run;
    hooks.onStarted?.call(run);
    return run;
  }

  /// Runs [steps] one after the other. The first step takes [input]; each
  /// later one takes its input from the step before ([ToolJob.chain]).
  Future<JobOutput> runChain(List<ChainStep> steps, Object? input) async {
    if (steps.isEmpty) throw ArgumentError('a chain needs a step');
    JobOutput? output;
    for (final step in steps) {
      final next = output == null
          ? input
          : _tools[step.toolId].chain(output, step.options);
      output = await (await start(step.toolId, next)).result;
    }
    return output!;
  }

  /// Jobs from an earlier launch that never ended (DK-0021 resumes or
  /// reports them).
  Future<List<UnfinishedJob>> unfinished() async => [
    for (final row in await _db.select(_db.jobs).get())
      if (!_running.containsKey(row.id))
        UnfinishedJob._(
          row.id,
          row.toolId,
          (jsonDecode(row.input) as Map).cast<String, Object?>(),
          row.startedAt,
        ),
  ];

  /// Runs an unfinished job again from the start (jobs never write in place,
  /// so a rerun is safe).
  Future<ToolRun> resume(UnfinishedJob job) async {
    final tool = _tools[job.toolId];
    final input = tool.decode(job.input);
    // Checked before its row goes: a job that can't run keeps its row, so
    // "Couldn't finish" can offer Try again (DK-0020, DK-0021).
    await preflight?.check(tool, input);
    await forget(job);
    return _start(job.toolId, input);
  }

  Future<void> forget(UnfinishedJob job) => _deleteRow(job.id);

  Future<JobOutput> _finish(ToolRun run, Future<JobOutput> result) async {
    try {
      final output = await result;
      _running.remove(run.id);
      await _deleteRow(run.id);
      await _db.recordToolRun(run.toolId, DateTime.now());
      hooks.onFinished?.call(run, output);
      return output;
    } catch (error) {
      _running.remove(run.id);
      await _deleteRow(run.id);
      if (error is! JobCancelled) hooks.onFailed?.call(run, error);
      rethrow;
    }
  }

  Future<void> _deleteRow(int id) =>
      (_db.delete(_db.jobs)..where((j) => j.id.equals(id))).go();

  /// Time left from the pages done so far, when the tool counts pages.
  static JobProgress _withEta(JobProgress p, Duration elapsed) {
    if (p.pageIndex == null || p.pageCount == null) return p;
    final done = p.pageIndex! + 1;
    return p.withEta(
      (elapsed.inMilliseconds * (p.pageCount! - done) / done / 1000).ceil(),
    );
  }
}

Future<JobOutput> _runTool(
  (ToolJob<Object?>, Object?) job,
  JobContext context,
) => job.$1.run(job.$2, ToolJobContext(context));
