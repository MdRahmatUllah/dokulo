import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'pp_ocr.dart';

/// The app's [OnnxRunner]: the bundled PP-OCRv5 models on ONNX Runtime
/// (flutter_onnxruntime, ORT 1.23), one session per model, kept open.
/// Inference runs in ONNX Runtime's native threads; [PpOcr]'s pre- and
/// post-processing belong on the ONNX lane, so a job on a background isolate
/// calls BackgroundIsolateBinaryMessenger.ensureInitialized first.
class FlutterOnnxRunner implements OnnxRunner {
  final _sessions = <String, Future<OrtSession>>{};

  static const _files = {
    'det': 'det.onnx',
    'cls': 'cls.onnx',
    'rec': 'rec_latin.onnx',
  };

  @override
  Future<(Float32List, List<int>)> run(
    String model,
    Float32List input,
    List<int> shape,
  ) async {
    final session = await (_sessions[model] ??= OnnxRuntime()
        .createSessionFromAsset(
          'packages/doc_vision/assets/ocr/${_files[model]}',
        ));
    final x = await OrtValue.fromList(input, shape);
    try {
      final outputs = await session.run({session.inputNames.first: x});
      final y = outputs[session.outputNames.first]!;
      try {
        final data = (await y.asFlattenedList()).map(
          (v) => (v as num).toDouble(),
        );
        return (Float32List.fromList(data.toList()), y.shape);
      } finally {
        await y.dispose();
      }
    } finally {
      await x.dispose();
    }
  }

  Future<void> close() async {
    for (final session in _sessions.values) {
      await (await session).close();
    }
    _sessions.clear();
  }
}
