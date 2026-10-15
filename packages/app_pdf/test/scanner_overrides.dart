import 'dart:typed_data';

import 'package:app_pdf/components/dk_camera_top_bar.dart';
import 'package:app_pdf/providers/camera_permission.dart';
import 'package:app_pdf/screens/s1_scanner/scan_session.dart';
import 'package:app_pdf/screens/s1_scanner/scanner_camera.dart';
import 'package:app_pdf/screens/s1_scanner/scanner_settings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// A camera that opens and shows nothing: these tests are about the screens around it.
class _FakeCamera implements ScannerCamera {
  @override
  Future<void> open() async {}
  @override
  Widget preview() => const SizedBox.expand();
  @override
  double? get aspectRatio => 3 / 4;
  @override
  Stream<GreyFrame> get frames => const Stream.empty();
  @override
  Future<void> setFlash(DkFlash flash) async {}
  @override
  Future<Uint8List> capture() async => Uint8List(0);
  @override
  Future<void> close() async {}
}

/// The camera is allowed: these tests are about the screens around it, not the permission.
class _Granted implements CameraPermission {
  @override
  Future<CameraAccess> status() async => CameraAccess.granted;
  @override
  Future<CameraAccess> request() async => CameraAccess.granted;
  @override
  Future<void> openSettings() async {}
}

/// S1 and S2 without the platform: the camera allowed and showing nothing,
/// the scan and the scanner's settings in memory.
List<Override> scannerOverrides() => [
  cameraPermissionProvider.overrideWithValue(_Granted()),
  scannerCameraProvider.overrideWith((ref) => _FakeCamera()),
  scanStoreProvider.overrideWithValue(MemoryScanStore()),
  scannerPrefsStoreProvider.overrideWithValue(MemoryPrefsStore()),
];
