import AVFoundation
import Flutter
import UIKit
import UserNotifications
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
      registerNotificationsChannel(registrar.messenger())
      registerMailChannel(registrar.messenger())
      registerLinksChannel(registrar.messenger())
      registerImagesChannel(registrar.messenger())
    }
  }

  /// Notices for long jobs (DK-0378; lib/providers/notification_permission.dart):
  /// granted, notAsked (show the pre-prompt) or denied. The app asks once.
  private func registerNotificationsChannel(_ messenger: FlutterBinaryMessenger) {
    func status(_ done: @escaping (String) -> Void) {
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        let s: String
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: s = "granted"
        case .notDetermined: s = "notAsked"
        default: s = "denied"
        }
        DispatchQueue.main.async { done(s) }
      }
    }
    FlutterMethodChannel(name: "dokulo/notifications", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "status":
          status { result($0) }
        case "request":
          status { current in
            guard current == "notAsked" else {
              result(current)
              return
            }
            UNUserNotificationCenter.current().requestAuthorization(
              options: [.alert, .sound]
            ) { _, _ in status { result($0) } }
          }
        default:
          result(FlutterMethodNotImplemented)
        }
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

  /// A web link in a PDF, after V1 asked (DK-1088; lib/providers/link_providers.dart).
  private func registerLinksChannel(_ messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "dokulo/links", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "open", let s = call.arguments as? String,
          let url = URL(string: s)
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        UIApplication.shared.open(url) { ok in result(ok) }
      }
  }

  /// HEIC/HEIF photos as JPEGs for the image tools (DK-1081;
  /// lib/providers/image_providers.dart): UIImage reads HEIC; drawn upright
  /// first, so the JPEG needs no orientation tag. Off the main thread.
  private func registerImagesChannel(_ messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "dokulo/images", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "heicToJpeg",
          let args = call.arguments as? [String: String],
          let from = args["from"], let to = args["to"]
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          var ok = false
          if let image = UIImage(contentsOfFile: from) {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            let upright = UIGraphicsImageRenderer(size: image.size, format: format)
              .image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
            if let data = upright.jpegData(compressionQuality: 0.92) {
              ok = (try? data.write(to: URL(fileURLWithPath: to))) != nil
            }
          }
          DispatchQueue.main.async { result(ok) }
        }
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
