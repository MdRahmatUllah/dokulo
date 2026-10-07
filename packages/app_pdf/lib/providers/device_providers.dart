import 'package:ai_core/ai_core.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_providers.g.dart';

/// The platform side: `MainActivity.kt` (Android) and `AppDelegate.swift` (iOS).
const deviceChannel = MethodChannel('dokulo/device');

/// What the phone can do (DK-0013). Kept alive: memory in all, the CPU and the
/// OS don't change while the app runs. A check that needs the free memory or
/// storage *now* (an AI model load, a job's preflight) invalidates it first.
/// A phone that won't answer reads as all-unknown, and no rule blocks on that.
@Riverpod(keepAlive: true)
Future<DeviceCapabilities> deviceCapabilities(Ref ref) async {
  try {
    final map = await deviceChannel.invokeMapMethod<Object?, Object?>(
      'capabilities',
    );
    return DeviceCapabilities.fromMap(map ?? const {});
  } on PlatformException {
    return const DeviceCapabilities();
  } on MissingPluginException {
    return const DeviceCapabilities();
  }
}

/// Whether Gemma (Summarize, Ask, Smart Split's check, Translate's best
/// engine) is offered on this phone: A1's readiness and "not eligible" sheet.
@riverpod
Future<AiEligibility> gemmaEligibility(Ref ref) async =>
    eligibility(await ref.watch(deviceCapabilitiesProvider.future), gemmaNeeds);
