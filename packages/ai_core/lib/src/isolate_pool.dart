/// The worker-isolate model (DK-0007; Technology plan, "Threading model").
///
/// PDFium is single-threaded, so every PDFium job runs on one long-lived
/// worker isolate, one job at a time. qpdf, OpenCV and ONNX jobs each get a
/// fresh isolate, so they run in parallel with each other and with PDFium.
/// The UI isolate never calls native code: a native binding calls
/// [assertWorkerIsolate] first, which fails in debug builds on any isolate
/// this pool did not start.
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
  /// The one PDFium isolate: its jobs run one after the other.
  pdfium,

  /// qpdf: a fresh isolate per job.
  qpdf,

  /// OpenCV: a fresh isolate per job.
  opencv,

  /// ONNX Runtime: a fresh isolate per job.
  onnx,
}

/// A job's body. It runs on a worker isolate, so it must be a top-level or
/// static function; its input and its result must be sendable between
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

/// Runs jobs on worker isolates. One pool per app.
class IsolatePool {
  /// [tempRoot] holds the jobs' temp directories (the system temp by default).
  IsolatePool({Directory? tempRoot})
    : _tempRoot = tempRoot ?? Directory.systemTemp;

  final Directory _tempRoot;
  Future<_Worker>? _pdfium;
  var _nextId = 0;

  /// Starts [body] with [input] on [lane].
  Job<R> run<A, R>(Lane lane, JobBody<A, R> body, A input) {
    final pending = _Pending<R>(_nextId++);
    _start(lane, pending, _bind(body, input));
    return Job._(pending);
  }

  /// Stops the PDFium worker; its unfinished jobs fail.
  Future<void> close() async {
    final pdfium = _pdfium;
    _pdfium = null;
    (await pdfium)?.isolate.kill();
  }

  Future<void> _start(Lane lane, _Pending<Object?> pending, _Task task) async {
    try {
      final temp = await _tempRoot.createTemp('dk_job_');
      if (pending.finished) {
        await temp.delete(); // cancelled meanwhile
        return;
      }
      pending.temp = temp;
      final _Worker worker;
      if (lane == Lane.pdfium) {
        worker = await (_pdfium ??= _Worker.spawn(
          'pdfium',
          onExit: () => _pdfium = null,
        ));
      } else {
        worker = await _Worker.spawn(lane.name, dedicated: true);
      }
      if (pending.finished) {
        if (worker.dedicated) worker.isolate.kill();
        await temp.delete(recursive: true);
        return;
      }
      worker.start(pending, task);
    } catch (e, s) {
      await pending.finish('failed', ('$e', '$s'));
    }
  }
}

// --- worker side -------------------------------------------------------------

typedef _Task = FutureOr<Object?> Function(JobContext context);

/// Binds a body to its input outside any instance method, so the closure
/// captures only these two (an instance method's closure may capture `this`,
/// which can't be sent to an isolate).
_Task _bind<A, R>(JobBody<A, R> body, A input) =>
    (context) => body(input, context);

bool _onWorker = false;

/// Fails (in debug builds, where asserts run) unless this isolate is a worker
/// of an [IsolatePool]. Every native binding calls it before its first native
/// call, so native code never runs on the UI isolate.
void assertWorkerIsolate() {
  assert(
    _onWorker,
    'Native code on an isolate the IsolatePool did not start: run it as a job (DK-0007).',
  );
}

void _workerMain(SendPort toMain) {
  _onWorker = true;
  final inbox = ReceivePort();
  toMain.send(inbox.sendPort);
  final contexts = <int, JobContext>{};
  var tail = Future<void>.value(); // jobs run one after the other
  inbox.listen((message) {
    switch (message) {
      case ('start', final int id, final _Task task, final String tempPath):
        final context = JobContext._(
          Directory(tempPath),
          (f) => toMain.send((id, 'progress', f)),
        );
        contexts[id] = context;
        tail = tail.then((_) async {
          try {
            if (context._cancelled) throw const JobCancelled();
            toMain.send((id, 'done', await task(context)));
          } on JobCancelled {
            toMain.send((id, 'cancelled', null));
          } catch (e, s) {
            toMain.send((id, 'failed', ('$e', '$s')));
          } finally {
            contexts.remove(id);
          }
        });
      case ('cancel', final int id):
        contexts[id]?._cancelled = true;
    }
  });
}

// --- main side ---------------------------------------------------------------

class _Worker {
  _Worker._(this.isolate, this.dedicated);

  final Isolate isolate;
  final bool dedicated;
  late final SendPort _toWorker;
  final _jobs = <int, _Pending<Object?>>{};

  static Future<_Worker> spawn(
    String name, {
    bool dedicated = false,
    void Function()? onExit,
  }) async {
    final inbox = ReceivePort();
    final exit = ReceivePort();
    final ready = Completer<SendPort>();
    final isolate = await Isolate.spawn(
      _workerMain,
      inbox.sendPort,
      debugName: 'dk-$name',
      onExit: exit.sendPort,
      errorsAreFatal: false,
    );
    final worker = _Worker._(isolate, dedicated);
    inbox.listen(
      (m) => m is SendPort
          ? ready.complete(m)
          : worker._handle(m as (int, String, Object?)),
    );
    exit.first.then((_) {
      exit.close();
      inbox.close();
      onExit?.call();
      for (final job in [...worker._jobs.values]) {
        job.finish(job.killed ? 'cancelled' : 'failed', (
          'worker isolate dk-$name exited',
          '',
        ));
      }
      worker._jobs.clear();
    });
    worker._toWorker = await ready.future;
    return worker;
  }

  void start(_Pending<Object?> job, _Task task) {
    _jobs[job.id] = job;
    job.onCancel = () {
      if (dedicated) {
        job.killed = true;
        isolate.kill(
          priority: Isolate.immediate,
        ); // the exit handler finishes it
      } else {
        _toWorker.send(('cancel', job.id));
      }
    };
    _toWorker.send(('start', job.id, task, job.temp!.path));
  }

  void _handle((int, String, Object?) message) {
    final (id, kind, value) = message;
    final job = _jobs[id];
    if (job == null) return;
    if (kind == 'progress') {
      job.progress.add(value!);
      return;
    }
    _jobs.remove(id);
    if (dedicated) isolate.kill();
    job.finish(kind, value);
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
      // Not on a worker yet: finish now; IsolatePool._start sees it.
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
