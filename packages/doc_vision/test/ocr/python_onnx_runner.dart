import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:doc_vision/doc_vision.dart';

/// Runs the real models on the development machine through
/// tools/ort_run.py (Python onnxruntime), for the OCR tests. Test-only.
class PythonOnnxRunner implements OnnxRunner {
  PythonOnnxRunner._(this._process, this._dir) {
    _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          _pending.removeAt(0).complete(line);
        });
  }

  final Process _process;
  final Directory _dir;
  final _pending = <Completer<String>>[];
  var _n = 0;

  /// Null when Python or onnxruntime isn't installed (the tests then skip).
  static Future<PythonOnnxRunner?> start(String repoRoot) async {
    final probe = await Process.run('python', [
      '-I',
      '-c',
      'import onnxruntime, numpy',
    ]);
    if (probe.exitCode != 0) return null;
    final process = await Process.start('python', [
      '-I',
      '$repoRoot/tools/ort_run.py',
      '$repoRoot/packages/doc_vision/assets/ocr',
    ]);
    process.stderr.transform(utf8.decoder).listen(stderr.write);
    return PythonOnnxRunner._(
      process,
      await Directory.systemTemp.createTemp('dk_ort_'),
    );
  }

  @override
  Future<(Float32List, List<int>)> run(
    String model,
    Float32List input,
    List<int> shape,
  ) async {
    final n = _n++;
    final inFile = File('${_dir.path}/in$n.bin')
      ..writeAsBytesSync(input.buffer.asUint8List());
    final outFile = File('${_dir.path}/out$n.bin');
    final answer = Completer<String>();
    _pending.add(answer);
    _process.stdin.writeln(
      jsonEncode({
        'model': model,
        'shape': shape,
        'in': inFile.path,
        'out': outFile.path,
      }),
    );
    final reply = jsonDecode(await answer.future) as Map<String, Object?>;
    final out = Float32List.view(outFile.readAsBytesSync().buffer);
    return (out, (reply['shape']! as List).cast<int>());
  }

  Future<void> close() async {
    await _process.stdin.close();
    await _process.exitCode;
    await _dir.delete(recursive: true);
  }
}
