import 'dart:io';

import 'package:flutter/foundation.dart' show VoidCallback;

import 'package:ai_core/ai_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'database_providers.dart';
import 'device_providers.dart';
import 'file_providers.dart';
import 'files_providers.dart';
import 'prefs_providers.dart';

part 'job_providers.g.dart';

/// The app's worker isolates (DK-0007). Job scratch directories go under the
/// sandbox, where the startup cleanup finds those of killed jobs.
@Riverpod(keepAlive: true)
Future<IsolatePool> isolatePool(Ref ref) async {
  final files = await ref.watch(fileStoreProvider.future);
  return IsolatePool(
    tempRoot: await _jobTempRoot(files.workDirectory).create(recursive: true),
  );
}

/// The one job queue (DK-0008).
@Riverpod(keepAlive: true)
Future<JobQueue> jobQueue(Ref ref) async => JobQueue(
  await ref.watch(isolatePoolProvider.future),
  ref.watch(appDatabaseProvider),
  ToolRegistry.app(),
  // Every started job shows in the mini job bar until it ends (DK-0233).
  hooks: JobHooks(onStarted: ref.read(runningJobsProvider.notifier).add),
  // No job starts that is known to fail; the free storage and memory are
  // read again for each (DK-0020).
  preflight: Preflight(() {
    ref.invalidate(deviceCapabilitiesProvider);
    return ref.read(deviceCapabilitiesProvider.future);
  }),
);

/// A running job and its latest progress, for the mini job bar.
class RunningJob {
  const RunningJob({
    required this.id,
    required this.toolId,
    required this.cancel,
    this.progress,
  });

  /// Its row in the jobs table.
  final int id;
  final String toolId;
  final VoidCallback cancel;
  final JobProgress? progress;

  RunningJob withProgress(JobProgress p) =>
      RunningJob(id: id, toolId: toolId, cancel: cancel, progress: p);
}

/// The jobs running now, oldest first (DK-0233): the mini job bar shows them
/// above any screen. A job leaves when it ends, however it ends (done,
/// failed or cancelled).
@Riverpod(keepAlive: true)
class RunningJobs extends _$RunningJobs {
  @override
  List<RunningJob> build() => const [];

  void add(ToolRun run) {
    state = [
      ...state,
      RunningJob(id: run.id, toolId: run.toolId, cancel: run.cancel),
    ];
    final updates = run.progress.listen(
      (p) => state = [
        for (final j in state) j.id == run.id ? j.withProgress(p) : j,
      ],
    );
    void remove() {
      updates.cancel();
      state = [
        for (final j in state)
          if (j.id != run.id) j,
      ];
    }

    // Done, failed or cancelled: the error is the tool screen's to show.
    run.result.then((_) => remove(), onError: (_) => remove());
  }
}

/// The launch cleanup and job recovery (DK-0021), run once. Home's continue
/// card and the mini bar read the report.
@Riverpod(keepAlive: true)
Future<StartupReport> startup(Ref ref) async {
  final files = await ref.watch(fileStoreProvider.future);
  return startupCleanup(
    db: ref.watch(appDatabaseProvider),
    files: files,
    queue: await ref.watch(jobQueueProvider.future),
    tools: ToolRegistry.app(),
    jobTempRoot: _jobTempRoot(files.workDirectory),
    // Read, not watched: a changed retention applies at the next launch.
    trashRetention: Duration(
      days: trashDays(await ref.read(prefsProvider.future)),
    ),
  );
}

Directory _jobTempRoot(Directory work) =>
    Directory('${work.path}${Platform.pathSeparator}jobs');
