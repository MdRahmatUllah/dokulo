import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'camera_permission.g.dart';

/// Where the camera permission stands (DK-0342).
enum CameraAccess {
  /// The scanner may open the camera.
  granted,

  /// The system has never asked: show the pre-prompt first.
  notAsked,

  /// Asked and refused (or restricted): show "Camera access is off" and
  /// never ask again from the app; only Settings can change it.
  denied,
}

/// The camera permission, behind an interface so tests can fake it.
abstract interface class CameraPermission {
  Future<CameraAccess> status();

  /// Shows the system prompt (once) and returns the answer.
  Future<CameraAccess> request();

  /// Opens this app's page in the system settings.
  Future<void> openSettings();
}

/// The platform side: `MainActivity.kt` (Android) and `AppDelegate.swift`
/// (iOS), channel `dokulo/camera`.
class PlatformCameraPermission implements CameraPermission {
  const PlatformCameraPermission();

  static const channel = MethodChannel('dokulo/camera');

  static CameraAccess _parse(String? s) =>
      CameraAccess.values.asNameMap()[s] ?? CameraAccess.denied;

  /// No channel (tests, desktop): granted, and the camera itself will say.
  @override
  Future<CameraAccess> status() async {
    try {
      return _parse(await channel.invokeMethod<String>('status'));
    } on MissingPluginException {
      return CameraAccess.granted;
    }
  }

  @override
  Future<CameraAccess> request() async =>
      _parse(await channel.invokeMethod<String>('request'));

  @override
  Future<void> openSettings() => channel.invokeMethod<void>('openSettings');
}

@Riverpod(keepAlive: true)
CameraPermission cameraPermission(Ref ref) => const PlatformCameraPermission();
