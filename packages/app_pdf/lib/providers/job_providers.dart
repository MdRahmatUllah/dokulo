import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'database_providers.dart';
import 'file_providers.dart';

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
);

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
  );
}

Directory _jobTempRoot(Directory work) =>
    Directory('${work.path}${Platform.pathSeparator}jobs');
