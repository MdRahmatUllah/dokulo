import AVFoundation
import Flutter
import UIKit
import os

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DokuloDevice") {
      registerDeviceChannel(registrar.messenger())
      registerCameraChannel(registrar.messenger())
      registerMailChannel(registrar.messenger())
    }
  }

  /// "Send report by email" (DK-1080; lib/providers/mail_providers.dart):
  /// the mailto draft opens in the user's mail app.
  private func registerMailChannel(_ messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "dokulo/mail", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "compose", let s = call.arguments as? String,
          let url = URL(string: s)
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        UIApplication.shared.open(url) { ok in result(ok) }
      }
  }

  /// The camera permission (DK-0342; lib/providers/camera_permission.dart):
  /// granted, notAsked (show the pre-prompt) or denied. The app asks once.
  private func registerCameraChannel(_ messenger: FlutterBinaryMessenger) {
    func status() -> String {
      switch AVCaptureDevice.authorizationStatus(for: .video) {
      case .authorized: return "granted"
      case .notDetermined: return "notAsked"
      default: return "denied"  // denied or restricted
      }
    }
    FlutterMethodChannel(name: "dokulo/camera", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "status":
          result(status())
        case "request":
          guard status() == "notAsked" else {
            result(status())
            return
          }
          AVCaptureDevice.requestAccess(for: .video) { _ in
            DispatchQueue.main.async { result(status()) }
          }
        case "openSettings":
          if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
  }

  /// What the phone can do (DK-0013; ai_core's DeviceCapabilities reads this map).
  private func registerDeviceChannel(_ messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "dokulo/device", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "capabilities" else {
          result(FlutterMethodNotImplemented)
          return
        }
        // The volume the app's files, and so the models, live on.
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? home.resourceValues(forKeys: [
          .volumeAvailableCapacityForImportantUsageKey,
          .volumeTotalCapacityKey,
        ])
        #if arch(arm64)
          let abi = "arm64"
        #else
          let abi = "x86_64"
        #endif
        let capabilities: [String: Any] = [
          "totalRam": Int64(ProcessInfo.processInfo.physicalMemory),
          // What this process may still allocate before iOS ends it.
          "availableRam": Int64(os_proc_available_memory()),
          "freeStorage": values?.volumeAvailableCapacityForImportantUsage ?? 0,
          "totalStorage": Int64(values?.volumeTotalCapacity ?? 0),
          "abis": [abi],
          "os": "ios",
          "osVersion": UIDevice.current.systemVersion,
        ]
        result(capabilities)
      }
  }
}
