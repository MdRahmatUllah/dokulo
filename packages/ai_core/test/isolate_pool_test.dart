import 'dart:io';
import 'dart:isolate';

import 'package:ai_core/ai_core.dart';
import 'package:test/test.dart';

// Job bodies run on worker isolates, so they are top-level functions.

void _spin(int ms) {
  final clock = Stopwatch()..start();
  while (clock.elapsedMilliseconds < ms) {}
}

int _calls = 0; // one per isolate

Future<int> _square(int n, JobContext context) async {
  context.progress(0.5);
  context.progress(1);
  return n * n;
}

/// (calls on this isolate so far, start µs, end µs).
(int, int, int) _stamp(int ms, JobContext context) {
  final start = DateTime.now().microsecondsSinceEpoch;
  _calls++;
  _spin(ms);
  return (_calls, start, DateTime.now().microsecondsSinceEpoch);
}

/// Writes a scratch file, then works in 50 ms chunks until cancelled.
Future<void> _politeLoop(void _, JobContext context) async {
  File('${context.tempDir.path}/scratch.bin')
      .writeAsBytesSync(List.filled(1024, 7));
  context.progress(0);
  while (true) {
    _spin(50);
    await context.checkCancelled();
  }
}

/// Writes a scratch file, then never yields: only a kill stops it.
void _stubbornLoop(void _, JobContext context) {
  File('${context.tempDir.path}/scratch.bin')
      .writeAsBytesSync(List.filled(1024, 7));
  context.progress(0);
  while (true) {}
}

int _throws(void _, JobContext context) => throw StateError('broken PDF');

String? _isolateName(void _, JobContext context) => Isolate.current.debugName;

/// Stands in for a PDFium call: pdfrx runs it on its own worker isolate.
Future<(int, int, int)> _viaPdfrxWorker(int ms, JobContext context) async {
  final start = DateTime.now().microsecondsSinceEpoch;
  await Isolate.run(() => _spin(ms));
  return (1, start, DateTime.now().microsecondsSinceEpoch);
}

String _nativeCall(void _, JobContext context) {
  assertWorkerIsolate();
  return Isolate.current.debugName ?? '';
}

void main() {
  late Directory tempRoot;
  late IsolatePool pool;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('dk_pool_test_');
    pool = IsolatePool(tempRoot: tempRoot);
  });

  tearDown(() => tempRoot.deleteSync(recursive: true));

  test('a job returns its result and reports progress', () async {
    final job = pool.run(Lane.qpdf, _square, 7);
    final progress = job.progress.toList();
    expect(await job.result, 49);
    expect(await progress, [0.5, 1.0]);
    expect(
      tempRoot.listSync(),
      isEmpty,
      reason: 'the temp directory goes with the job',
    );
  });

  test(
    'PDFium jobs run on the calling isolate (pdfrx has the one PDFium worker)',
    () async {
      final before = _calls;
      final (calls, _, _) = await pool.run(Lane.pdfium, _stamp, 10).result;
      expect(calls, before + 1, reason: "this isolate's counter");
      expect(
        await pool.run(Lane.pdfium, _isolateName, null).result,
        Isolate.current.debugName,
      );
    },
  );

  test(
    'qpdf, OpenCV and ONNX jobs get isolates of their own and overlap',
    () async {
      final a = pool.run(Lane.qpdf, _stamp, 400);
      final b = pool.run(Lane.qpdf, _stamp, 400);
      final (callsA, startA, endA) = await a.result;
      final (callsB, startB, endB) = await b.result;
      expect((callsA, callsB), (1, 1), reason: 'a fresh isolate each');
      expect(
        startB < endA && startA < endB,
        isTrue,
        reason: 'they ran at the same time',
      );
    },
  );

  test(
    'cancelling a PDFium job stops it within 1 s and frees its temp files',
    () async {
      final job = pool.run(Lane.pdfium, _politeLoop, null);
      await job.progress.first; // it has started and written its scratch file
      expect(tempRoot.listSync(), hasLength(1));
      final clock = Stopwatch()..start();
      job.cancel();
      await expectLater(job.result, throwsA(isA<JobCancelled>()));
      expect(clock.elapsedMilliseconds, lessThan(1000));
      expect(tempRoot.listSync(), isEmpty);
      expect(
        await pool.run(Lane.pdfium, _square, 3).result,
        9,
        reason: 'the PDFium lane keeps working',
      );
    },
  );

  test('cancelling a job on its own isolate kills it within 1 s, even if it never yields', () async {
    final job = pool.run(Lane.onnx, _stubbornLoop, null);
    await job.progress.first;
    final clock = Stopwatch()..start();
    job.cancel();
    await expectLater(job.result, throwsA(isA<JobCancelled>()));
    expect(clock.elapsedMilliseconds, lessThan(1000));
    expect(tempRoot.listSync(), isEmpty);
  });

  test('a job cancelled before it starts never runs', () async {
    final job = pool.run(Lane.opencv, _square, 2)..cancel();
    await expectLater(job.result, throwsA(isA<JobCancelled>()));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(tempRoot.listSync(), isEmpty);
  });

  test('an error in a job fails it with its message', () async {
    final job = pool.run(Lane.pdfium, _throws, null);
    await expectLater(
      job.result,
      throwsA(
        isA<JobFailed>().having(
          (e) => e.message,
          'message',
          contains('broken PDF'),
        ),
      ),
    );
    expect(
      await pool.run(Lane.pdfium, _square, 4).result,
      16,
      reason: 'one failure does not stop the lane',
    );
  });

  test(
    'native calls are allowed on workers and fail on any other isolate',
    () async {
      expect(
        pool.run(Lane.pdfium, _nativeCall, null).result,
        throwsA(isA<JobFailed>()),
        reason: 'PDFium jobs reach PDFium only through pdfrx',
      );
      expect(
        await pool.run(Lane.opencv, _nativeCall, null).result,
        'dk-opencv',
      );
      expect(
        assertWorkerIsolate,
        throwsA(isA<AssertionError>()),
        reason: 'this test isolate stands in for the UI',
      );
    },
  );

  test('stress: merge, compress and OCR at once leave the calling isolate free', () async {
    // Three 600 ms jobs, one per kind of engine. Meanwhile the calling isolate
    // (the UI's stand-in) hops through its event loop and measures the longest
    // gap between hops: no gap may reach a frame (16 ms). Zero-delay hops, not
    // a periodic timer, because Windows timers tick every ~15.6 ms. The device
    // check on a mid Android phone is SQA's.
    final jobs = [
      pool.run(Lane.pdfium, _viaPdfrxWorker, 600), // merge
      pool.run(Lane.qpdf, _stamp, 600), // compress
      pool.run(Lane.onnx, _stamp, 600), // OCR
    ];
    var done = false;
    final all = Future.wait(jobs.map((j) => j.result))
        .whenComplete(() => done = true);
    final clock = Stopwatch()..start();
    var last = 0, worstGap = 0;
    while (!done) {
      await Future<void>.delayed(Duration.zero);
      final now = clock.elapsedMicroseconds;
      if (now - last > worstGap) worstGap = now - last;
      last = now;
    }
    await all;
    expect(worstGap, lessThan(16000), reason: 'longest event-loop gap, µs');
  });
}
