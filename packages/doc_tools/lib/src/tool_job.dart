import 'dart:async';
import 'dart:io';

import 'package:ai_core/ai_core.dart';

/// Where a job is, for the X2 progress sheet ("Page 7 of 40", time left).
/// Page-based tools report at least once per page.
class JobProgress {
  const JobProgress(
    this.stage, {
    this.pageIndex,
    this.pageCount,
    this.bytesDone,
    this.etaSeconds,
  });

  /// What the job is doing, as a key the UI translates (`reading`, `writing`, …).
  final String stage;

  /// The page being worked on, from 0.
  final int? pageIndex;
  final int? pageCount;
  final int? bytesDone;

  /// Time left; the job queue estimates it from the pages done so far.
  final int? etaSeconds;

  /// Pages done as a fraction, when the tool counts pages.
  double? get fraction =>
      (pageIndex != null && pageCount != null && pageCount! > 0)
      ? ((pageIndex! + 1) / pageCount!).clamp(0.0, 1.0)
      : null;

  JobProgress withEta(int? seconds) => JobProgress(
    stage,
    pageIndex: pageIndex,
    pageCount: pageCount,
    bytesDone: bytesDone,
    etaSeconds: seconds,
  );

  @override
  String toString() =>
      'JobProgress($stage, page ${pageIndex ?? '-'}/${pageCount ?? '-'}, eta $etaSeconds s)';
}

/// What a tool made: one file, many files, or text. JSON, so a workflow step
/// can hand it to the next one.
sealed class JobOutput {
  const JobOutput();

  Map<String, Object?> toJson();

  static JobOutput fromJson(Map<String, Object?> json) => switch (json) {
    {'file': final String path} => OneFile(path),
    {'files': final List<Object?> paths} => ManyFiles(paths.cast<String>()),
    {'text': final String text} => TextOutput(text),
    _ => throw FormatException('not a JobOutput: $json'),
  };
}

final class OneFile extends JobOutput {
  const OneFile(this.path);
  final String path;

  @override
  Map<String, Object?> toJson() => {'file': path};
}

final class ManyFiles extends JobOutput {
  const ManyFiles(this.paths);
  final List<String> paths;

  @override
  Map<String, Object?> toJson() => {'files': paths};
}

final class TextOutput extends JobOutput {
  const TextOutput(this.text);
  final String text;

  @override
  Map<String, Object?> toJson() => {'text': text};
}

/// What a running tool sees.
class ToolJobContext {
  ToolJobContext(this._job);

  final JobContext _job;

  /// Scratch files; deleted when the job ends. Outputs go where the input says.
  Directory get tempDir => _job.tempDir;

  bool get isCancelled => _job.isCancelled;

  void report(JobProgress progress) => _job.progress(progress);

  /// Throws [JobCancelled] once cancelled; call it between pages.
  Future<void> checkCancelled() => _job.checkCancelled();
}

/// One tool's engine (T2 → X2 → T3): typed input in, [JobOutput] out, on its
/// [lane]. A subclass is a const class with no state, so it can be sent to a
/// worker isolate. It never writes into the input file: the output is always
/// a new file (Developer guide §1).
abstract class ToolJob<I> {
  const ToolJob();

  /// The tool's id, as in `/tool/:toolId` (`merge`, `compress`, …).
  String get id;

  Lane get lane;

  /// The input as JSON (the jobs table, workflows) and back.
  Map<String, Object?> encode(I input);
  I decode(Map<String, Object?> json);

  /// The files [input] reads. A job killed with the app is resumed at the
  /// next launch only if they all still exist (DK-0021). Outputs don't count.
  List<String> inputFiles(I input) => const [];

  /// This tool's input when it follows another one in a chain: the previous
  /// step's output plus this step's saved options.
  I chain(JobOutput previous, Map<String, Object?> options);

  /// Does the work: on a worker isolate, or for [Lane.pdfium] on the calling
  /// isolate with every PDFium call through pdfrx. Reports [JobProgress] at
  /// least once per page for a page-based tool.
  Future<JobOutput> run(I input, ToolJobContext context);
}

/// A copy of a file taken before "Replace original", so it can be put back
/// (Undo for 10 s; the versions table keeps it longer, DK-0277).
class UndoSnapshot {
  UndoSnapshot._(this.original, this.copy);

  final String original;
  final String copy;

  /// Copies [original] into [dir].
  static Future<UndoSnapshot> take(String original, Directory dir) async {
    final name = original.split(RegExp(r'[\\/]')).last;
    final copy = await File(original).copy(
      '${dir.path}${Platform.pathSeparator}${DateTime.now().microsecondsSinceEpoch}_$name',
    );
    return UndoSnapshot._(original, copy.path);
  }

  /// Puts the copy back over the original.
  Future<void> restore() => File(copy).copy(original);

  Future<void> discard() => File(copy).delete();
}
