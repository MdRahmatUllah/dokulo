import 'package:doc_tools/doc_tools.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../providers/file_providers.dart';
import '../../providers/job_providers.dart';

part 'tool_run.g.dart';

/// A tool run as T2 follows it: its progress, its end, a way to stop it,
/// and a way to drop what it wrote (after a cancel or a failure, DK-0376).
typedef ToolRunHandle = ({
  Stream<JobProgress> progress,
  Future<Object?> result,
  VoidCallback cancel,
  Future<void> Function() discard,
});

/// Starts a tool's job with [input] made for a fresh temp output folder (the
/// app: the JobQueue and the file store; tests: a simulated run).
typedef ToolRunner = Future<ToolRunHandle> Function(
  String toolId,
  Object Function(String outputDir) input,
);

@Riverpod(keepAlive: true)
ToolRunner toolRunner(Ref ref) => (toolId, input) async {
  final store = await ref.read(fileStoreProvider.future);
  final out = await store.workDirectory.createTemp('${toolId}_');
  final queue = await ref.read(jobQueueProvider.future);
  try {
    final run = await queue.start(toolId, input(out.path));
    return (
      progress: run.progress,
      result: run.result,
      cancel: run.cancel,
      discard: () async {
        if (await out.exists()) await out.delete(recursive: true);
      },
    );
  } catch (_) {
    // Refused by the preflight: nothing ran, nothing to keep.
    await out.delete(recursive: true);
    rethrow;
  }
};

/// How a running job shows in T2 (UI spec §20.2; DK-0375).
enum X2Phase {
  /// Under 2 s: nothing but the button's press.
  quiet,

  /// 2–10 s: the main button's loading state ("Compressing…").
  button,

  /// From 10 s: the progress sheet.
  sheet,
}

/// When the button starts loading, and when the sheet slides up.
const x2Button = Duration(seconds: 2), x2Sheet = Duration(seconds: 10);

X2Phase x2PhaseAt(Duration elapsed) => elapsed < x2Button
    ? X2Phase.quiet
    : elapsed < x2Sheet
    ? X2Phase.button
    : X2Phase.sheet;

/// Cancelling a job that has run longer than this asks first (DK-0376).
const confirmCancelAfter = Duration(seconds: 30);

/// The time left, smoothed: never more than 50 % up or down from the last
/// shown value (DK-0375), so the estimate doesn't jump.
int smoothEta(int? shown, int raw) => shown == null || shown == 0
    ? raw
    : raw.clamp((shown * 0.5).ceil(), (shown * 1.5).floor());
