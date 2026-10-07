import 'dart:io';

import 'package:doc_core/doc_core.dart';

import 'job_queue.dart';
import 'registry.dart';

/// What [startupCleanup] did, for Home's continue card and the mini bar.
class StartupReport {
  const StartupReport({
    required this.resumed,
    required this.couldNotFinish,
    required this.trashPurged,
    required this.indexing,
  });

  /// Jobs killed with the app and started again ("continue").
  final List<ToolRun> resumed;

  /// Jobs that can't run again (their input is gone, or the tool is): Home
  /// shows "Couldn't finish {tool}" with Try again ([JobQueue.resume]); its
  /// row stays until the user acts ([JobQueue.forget]).
  final List<UnfinishedJob> couldNotFinish;

  /// Files deleted from Recently deleted, past the retention.
  final int trashPurged;

  /// Step 4, still running in the background: how many files got their
  /// Files-search text indexed ([TextIndexer], DK-0270).
  final Future<int> indexing;
}

/// Runs once at launch (DK-0021), before any new job:
///
/// 1. Empties the sandbox's temp and inbox, and the job scratch directories
///    in [jobTempRoot]: everything there is from an earlier session. Jobs
///    write output to temp and only [FileStore.save] moves it into the user
///    folder, so a job killed mid-run leaves nothing partial there.
/// 2. Deletes files that sat in Recently deleted longer than [trashRetention].
/// 3. Resumes each job the OS killed whose input files still exist; reports
///    the rest.
/// 4. Brings the file index in line with the user folder and indexes the
///    text of every file that isn't yet ([TextIndexer]), in the background:
///    a file whose indexing a kill interrupted is finished here.
Future<StartupReport> startupCleanup({
  required DokuloDatabase db,
  required FileStore files,
  required JobQueue queue,
  required ToolRegistry tools,
  Directory? jobTempRoot,
  Duration trashRetention = const Duration(days: 30),
  DateTime? now,
}) async {
  await files.clearTemp();
  // Resumed jobs write their output there again.
  await files.temp.create(recursive: true);
  if (jobTempRoot != null && await jobTempRoot.exists()) {
    await for (final entry in jobTempRoot.list()) {
      if (entry is Directory &&
          entry.uri.pathSegments
              .where((s) => s.isNotEmpty)
              .last
              .startsWith('dk_job_')) {
        await entry.delete(recursive: true);
      }
    }
  }

  final cutoff = (now ?? DateTime.now()).subtract(trashRetention);
  final expired = await db.expiredTrash(cutoff).get();
  for (final file in expired) {
    final onDisk = File(file.path);
    if (await onDisk.exists()) await onDisk.delete();
    await (db.delete(
      db.files,
    )..where((f) => f.id.equals(file.id))).go(); // cascades to trash
  }

  final resumed = <ToolRun>[];
  final couldNotFinish = <UnfinishedJob>[];
  for (final job in await queue.unfinished()) {
    if (await _canResume(tools, job)) {
      resumed.add(await queue.resume(job));
    } else {
      couldNotFinish.add(job);
    }
  }
  return StartupReport(
    resumed: resumed,
    couldNotFinish: couldNotFinish,
    trashPurged: expired.length,
    indexing: files.reconcile(db).then((_) => TextIndexer(db).catchUp()),
  );
}

Future<bool> _canResume(ToolRegistry tools, UnfinishedJob job) async {
  if (!tools.ids.contains(job.toolId)) return false;
  final tool = tools[job.toolId];
  final List<String> inputs;
  try {
    inputs = tool.inputFiles(tool.decode(job.input));
  } catch (_) {
    return false; // stored by an older app version that read it differently
  }
  for (final path in inputs) {
    if (!await File(path).exists()) return false;
  }
  return true;
}
