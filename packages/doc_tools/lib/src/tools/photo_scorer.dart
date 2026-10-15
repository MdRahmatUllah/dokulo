import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:doc_vision/doc_vision.dart';
import 'package:flutter/services.dart'
    show BackgroundIsolateBinaryMessenger, RootIsolateToken;

export 'package:doc_vision/doc_vision.dart' show documentThreshold;

/// Scores library thumbnails for the photo finder (DK-0362) on one
/// long-lived worker isolate: the decode and the page quad (OpenCV), the
/// platform's OCR (Vision on iOS, PP-OCRv5 elsewhere) and [documentScore]
/// all run there; the UI isolate only sends a JPEG and gets a number back.
/// No network: the models are bundled.
class DocumentPhotoScorer {
  DocumentPhotoScorer({
    Future<OcrAssets?> Function()? assets,
    Future<OcrEngine> Function(OcrAssets?)? engine,
  }) : _assets = assets ?? OcrEngine.loadAssets,
       _engine = engine ?? _platformEngine;

  /// Loaded here (rootBundle only works on the root isolate); tests: null.
  final Future<OcrAssets?> Function() _assets;

  /// Made on the worker; tests put a fake here.
  final Future<OcrEngine> Function(OcrAssets?) _engine;

  Future<SendPort>? _worker;

  Future<SendPort> _start() async {
    final ready = ReceivePort();
    await Isolate.spawn(_serve, (
      reply: ready.sendPort,
      assets: await _assets(),
      token: RootIsolateToken.instance,
      engine: _engine,
    ));
    return await ready.first as SendPort;
  }

  /// [image]'s score, 0–1. Throws what the worker threw for this photo.
  Future<double> call(Uint8List image) async {
    final worker = await (_worker ??= _start());
    final answer = ReceivePort();
    worker.send((image: image, reply: answer.sendPort));
    final result = await answer.first;
    answer.close();
    if (result is double) return result;
    throw StateError('scoring failed: $result');
  }

  /// Stops the worker and its OCR engine.
  Future<void> close() async {
    final worker = await _worker;
    _worker = null;
    // The worker closes its engine and its port, and ends.
    worker?.send(null);
  }
}

Future<OcrEngine> _platformEngine(OcrAssets? assets) =>
    OcrEngine.forPlatform(assets: assets);

/// The worker: one OCR engine for the scan, one photo at a time.
Future<void> _serve(
  ({
    SendPort reply,
    OcrAssets? assets,
    RootIsolateToken? token,
    Future<OcrEngine> Function(OcrAssets?) engine,
  })
  setup,
) async {
  if (setup.token case final token?) {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token); // ONNX, Vision
  }
  final inbox = ReceivePort();
  setup.reply.send(inbox.sendPort);
  OcrEngine? engine;
  await for (final message in inbox) {
    if (message == null) break;
    final (:Uint8List image, :SendPort reply) =
        message as ({Uint8List image, SendPort reply});
    try {
      final decoded = decodeForScoring(image);
      if (decoded == null) {
        reply.send(0.0);
        continue;
      }
      engine ??= await setup.engine(setup.assets);
      final ocr = await engine.recognizeRaster(
        decoded.raster,
        scratch: Directory.systemTemp,
      );
      reply.send(
        documentScore(
          width: decoded.raster.width,
          height: decoded.raster.height,
          words: ocr.words,
          quad: decoded.quad,
        ),
      );
    } catch (e) {
      reply.send('$e');
    }
  }
  inbox.close();
  await engine?.close();
}
