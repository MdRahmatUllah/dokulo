import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../components/dk_camera_top_bar.dart';

part 'scanner_camera.g.dart';

/// One preview frame's luminance (the camera's Y plane): enough for the quad
/// detector, with no colour conversion on every frame.
@immutable
class GreyFrame {
  const GreyFrame(
    this.bytes,
    this.width,
    this.height, {
    required this.rowStride,
    required this.time,
  });
  final Uint8List bytes;
  final int width, height, rowStride;

  /// When it was taken, for the quad tracker's steadiness.
  final Duration time;
}

/// The scanner's camera (S1, DK-0343), behind an interface so the screen
/// can be tested and the platform engines (DK-0336/0337) can feed it.
abstract interface class ScannerCamera {
  /// Opens the back camera. Throws [CameraUnavailable] when there is none
  /// or access was taken away meanwhile.
  Future<void> open();

  /// The preview, sized by the camera's aspect ratio ([aspectRatio]).
  Widget preview();

  /// Width / height of the preview in portrait; null before [open].
  double? get aspectRatio;

  /// Preview frames for the detector.
  Stream<GreyFrame> get frames;

  Future<void> setFlash(DkFlash flash);

  /// A full-resolution JPEG of the page.
  Future<Uint8List> capture();

  Future<void> close();
}

class CameraUnavailable implements Exception {
  const CameraUnavailable(this.reason);
  final String reason;
  @override
  String toString() => 'CameraUnavailable: $reason';
}

/// [ScannerCamera] on the `camera` plugin: CameraX on Android, AVFoundation
/// on iOS. Frames are the image stream's first plane: Y, with YUV 4:2:0 on
/// both platforms.
class PluginScannerCamera implements ScannerCamera {
  CameraController? _controller;
  final _frames = StreamController<GreyFrame>.broadcast();
  final _clock = Stopwatch();

  @override
  Future<void> open() async {
    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on Exception catch (e) {
      // No plugin (tests, desktop) or the platform refused.
      throw CameraUnavailable('$e');
    }
    final back = cameras.where(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    if (back.isEmpty) throw const CameraUnavailable('no back camera');
    final c = CameraController(
      back.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    try {
      await c.initialize();
    } on CameraException catch (e) {
      await c.dispose();
      throw CameraUnavailable(e.code);
    }
    _controller = c;
    _clock.start();
    await c.startImageStream((image) {
      // The screen drops frames while its detector is busy.
      if (!_frames.hasListener) return;
      final y = image.planes.first;
      _frames.add(
        GreyFrame(
          y.bytes,
          image.width,
          image.height,
          rowStride: y.bytesPerRow,
          time: _clock.elapsed,
        ),
      );
    });
  }

  @override
  Widget preview() {
    final c = _controller;
    return c == null ? const SizedBox.shrink() : CameraPreview(c);
  }

  @override
  double? get aspectRatio {
    final c = _controller;
    // The plugin reports landscape; the scanner is portrait.
    return c == null || !c.value.isInitialized ? null : 1 / c.value.aspectRatio;
  }

  @override
  Stream<GreyFrame> get frames => _frames.stream;

  @override
  Future<void> setFlash(DkFlash flash) async =>
      _controller?.setFlashMode(switch (flash) {
        DkFlash.off => FlashMode.off,
        DkFlash.on => FlashMode.always,
        DkFlash.auto => FlashMode.auto,
      });

  @override
  Future<Uint8List> capture() async {
    final c = _controller;
    if (c == null) throw const CameraUnavailable('not open');
    final shot = await c.takePicture();
    return shot.readAsBytes();
  }

  @override
  Future<void> close() async {
    final c = _controller;
    _controller = null;
    if (c != null) {
      if (c.value.isStreamingImages) await c.stopImageStream();
      await c.dispose();
    }
    await _frames.close();
  }
}

/// A new camera for each scanner screen (it is opened and closed with it).
@riverpod
ScannerCamera scannerCamera(Ref ref) => PluginScannerCamera();
