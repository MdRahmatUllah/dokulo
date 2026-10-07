/// The worker-isolate model (DK-0007, DK-1044; Technology plan, "Threading
/// model").
///
/// PDFium is single-threaded. pdfrx runs every PDFium call on its own worker
/// isolate, one worker per Dart isolate, and the viewer uses pdfrx from the UI
/// isolate. A second worker would be a second thread in PDFium, so a PDFium
/// job runs on the calling isolate and reaches PDFium only through pdfrx (its
/// API, `PdfrxEntryFunctions.instance.compute`, or
/// `PdfDocument.useNativeDocumentHandle`), serialised with the viewer on
/// pdfrx's one worker. qpdf, OpenCV and ONNX jobs each get a fresh isolate, so
/// they run in parallel. Our own native bindings call [assertWorkerIsolate]
/// first, which fails in debug builds on any isolate this pool did not start,
/// so they never run on the UI isolate.
///
/// It lives in `ai_core`, the bottom layer, because `doc_core`, `doc_vision`
/// and `ai_core` itself all run native code, and the layer rule lets each of
/// them depend only on a lower layer.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

/// Where a job runs.
enum Lane {
  /// PDFium through pdfrx: the job runs on the calling isolate; pdfrx runs
  /// every PDFium call on its one worker.
  pdfium,

  /// qpdf: a fresh isolate per job.
  qpdf,

  /// OpenCV: a fresh isolate per job.
  opencv,

  /// ONNX Runtime: a fresh isolate per job.
  onnx,
}

/// A job's body. On a worker isolate (every lane but [Lane.pdfium]), so it is
/// a top-level or static function whose input and result are sendable between
/// isolates (numbers, strings, lists, maps, records, typed data, …).
typedef JobBody<A, R> = FutureOr<R> Function(A input, JobContext context);

/// The result of a job that was cancelled.
class JobCancelled implements Exception {
  const JobCancelled();

  @override
  String toString() => 'JobCancelled';
}

/// The result of a job that threw on its worker, or whose worker died. The
/// error comes over as text: an exception object need not be sendable.
class JobFailed implements Exception {
  JobFailed(this.message, [this.stackTrace = '']);

  final String message;
  final String stackTrace;

  @override
  String toString() => 'JobFailed: $message';
}

/// What a running job sees, on its worker isolate.
class JobContext {
  JobContext._(this.tempDir, this._report);

  /// A fresh directory for the job's scratch files. It is deleted when the job
  /// ends, however it ends; the job writes its output where its input says.
  final Directory tempDir;
  final void Function(Object) _report;
  bool _cancelled = false;

  /// Whether the job was cancelled; [checkCancelled] acts on it.
  bool get isCancelled => _cancelled;

  /// Reports progress: a fraction from 0 to 1, or a richer sendable value
  /// (doc_tools sends its `JobProgress`).
  void progress(Object update) => _report(update);

  /// Throws [JobCancelled] once the job is cancelled. Call it between chunks
  /// of native work, and keep a chunk well under a second: a cancel must stop
  /// native work within 1 s (DK-0007).
  Future<void> checkCancelled() async {
    await Future<void>.delayed(Duration.zero); // lets a cancel message in
    if (_cancelled) throw const JobCancelled();
  }
}

/// A started job.
class Job<R> {
  Job._(this._pending);

  final _Pending<R> _pending;

  /// Progress as the job reports it ([JobContext.progress]). Listen right
  /// away: it is a broadcast stream, so earlier events are not replayed.
  Stream<Object> get progress => _pending.progress.stream;

  /// The job's result. It fails with [JobCancelled] or [JobFailed]; by the time
  /// it completes, the job's temp directory is gone.
  Future<R> get result => _pending.result.future;

  /// Stops the job. A job on its own isolate is killed at once; a PDFium job
  /// stops at its next [JobContext.checkCancelled].
  void cancel() => _pending.cancel();
}

/// Runs jobs: PDFium jobs here, the others on worker isolates. One pool per
/// app.
class IsolatePool {
  /// [tempRoot] holds the jobs' temp directories (the system temp by default).
  IsolatePool({Directory? tempRoot})
    : _tempRoot = tempRoot ?? Directory.systemTemp;

  final Directory _tempRoot;
  var _nextId = 0;

  /// Starts [body] with [input] on [lane].
  Job<R> run<A, R>(Lane lane, JobBody<A, R> body, A input) {
    final pending = _Pending<R>(_nextId++);
    _start(lane, pending, _bind(body, input));
    return Job._(pending);
  }

  Future<void> _start(Lane lane, _Pending<Object?> pending, _Task task) async {
    try {
      final temp = await _tempRoot.createTemp('dk_job_');
      if (pending.finished) {
        await temp.delete(); // cancelled meanwhile
        return;
      }
      pending.temp = temp;
      if (lane == Lane.pdfium) {
        await _runHere(pending, task);
      } else {
        await _runOnWorker(lane.name, pending, task);
      }
    } catch (e, s) {
      await pending.finish('failed', ('$e', '$s'));
    }
  }
}

typedef _Task = FutureOr<Object?> Function(JobContext context);

/// Binds a body to its input outside any instance method, so the closure
/// captures only these two (an instance method's closure may capture `this`,
/// which can't be sent to an isolate).
_Task _bind<A, R>(JobBody<A, R> body, A input) =>
    (context) => body(input, context);

/// A PDFium job: here, cancelled at its next [JobContext.checkCancelled].
Future<void> _runHere(_Pending<Object?> job, _Task task) async {
  final context = JobContext._(job.temp!, job.progress.add);
  job.onCancel = () => context._cancelled = true;
  try {
    final result = await task(context);
    await job.finish('done', result);
  } on JobCancelled {
    await job.finish('cancelled', null);
  } catch (e, s) {
    await job.finish('failed', ('$e', '$s'));
  }
}

/// Any other job: on a fresh isolate, killed by a cancel.
Future<void> _runOnWorker(
  String name,
  _Pending<Object?> job,
  _Task task,
) async {
  final inbox = ReceivePort(); // the job's messages, then null when it exits
  final isolate = await Isolate.spawn(
    _workerMain,
    (inbox.sendPort, task, job.temp!.path),
    debugName: 'dk-$name',
    onExit: inbox.sendPort,
  );
  job.onCancel = () {
    job.killed = true;
    isolate.kill(priority: Isolate.immediate);
  };
  if (job.finished) isolate.kill(); // cancelled while it spawned
  await for (final message in inbox) {
    switch (message) {
      case ('progress', final Object update) when !job.finished:
        job.progress.add(update);
      case (final String kind, final Object? value) when kind != 'progress':
        await job.finish(kind, value);
      case null:
        inbox.close();
        await job.finish(job.killed ? 'cancelled' : 'failed', (
          'worker isolate dk-$name exited',
          '',
        ));
    }
  }
}

bool _onWorker = false;

/// Fails (in debug builds, where asserts run) unless this isolate is a worker
/// of an [IsolatePool]. Every native binding of ours (qpdf, OpenCV, ONNX,
/// llama.cpp) calls it before its first native call, so native code never
/// runs on the UI isolate. PDFium is reached only through pdfrx.
void assertWorkerIsolate() {
  assert(
    _onWorker,
    'Native code on an isolate the IsolatePool did not start: run it as a job (DK-0007).',
  );
}

Future<void> _workerMain((SendPort, _Task, String) start) async {
  _onWorker = true;
  final (toMain, task, tempPath) = start;
  final context = JobContext._(
    Directory(tempPath),
    (update) => toMain.send(('progress', update)),
  );
  try {
    toMain.send(('done', await task(context)));
  } on JobCancelled {
    toMain.send(('cancelled', null));
  } catch (e, s) {
    toMain.send(('failed', ('$e', '$s')));
  }
}

class _Pending<R> {
  _Pending(this.id);

  final int id;
  final progress = StreamController<Object>.broadcast();
  final result = Completer<R>();
  Directory? temp;
  void Function()? onCancel;
  bool _cancelRequested = false;
  bool killed = false;
  bool _finished = false;

  bool get finished => _finished;

  void cancel() {
    if (_finished || _cancelRequested) return;
    _cancelRequested = true;
    if (onCancel != null) {
      onCancel!();
    } else {
      // Not started yet: finish now; IsolatePool._start sees it.
      finish('cancelled', null);
    }
  }

  Future<void> finish(String kind, Object? value) async {
    if (_finished) return;
    _finished = true;
    try {
      await temp?.delete(recursive: true);
    } on FileSystemException {
      // Already gone.
    }
    await progress.close();
    switch (kind) {
      case 'done':
        result.complete(value as R);
      case 'cancelled':
        result.completeError(const JobCancelled());
      default:
        final (message, stack) = value! as (String, String);
        result.completeError(JobFailed(message, stack));
    }
  }
}
