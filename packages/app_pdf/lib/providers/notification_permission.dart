import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_permission.g.dart';

/// Where the notifications permission stands (DK-0378).
enum NotificationAccess {
  /// Notices can be shown.
  granted,

  /// The system has never asked: the app may show its pre-prompt.
  notAsked,

  /// Asked and refused, or turned off: the app never asks again.
  denied,
}

/// The notifications permission, behind an interface so tests can fake it.
abstract interface class NotificationPermission {
  Future<NotificationAccess> status();

  /// Shows the system prompt (once) and returns the answer.
  Future<NotificationAccess> request();
}

/// The platform side: `MainActivity.kt` (Android 13+ POST_NOTIFICATIONS;
/// older Androids only report whether notices are on) and
/// `AppDelegate.swift` (UNUserNotificationCenter), channel
/// `dokulo/notifications`. No plugin: two calls are all it takes.
class PlatformNotificationPermission implements NotificationPermission {
  const PlatformNotificationPermission();

  static const channel = MethodChannel('dokulo/notifications');

  static NotificationAccess _parse(String? s) =>
      NotificationAccess.values.asNameMap()[s] ?? NotificationAccess.denied;

  /// No channel (tests, desktop): denied, so nothing asks.
  @override
  Future<NotificationAccess> status() async {
    try {
      return _parse(await channel.invokeMethod<String>('status'));
    } on MissingPluginException {
      return NotificationAccess.denied;
    }
  }

  @override
  Future<NotificationAccess> request() async {
    try {
      return _parse(await channel.invokeMethod<String>('request'));
    } on MissingPluginException {
      return NotificationAccess.denied;
    }
  }
}

@Riverpod(keepAlive: true)
NotificationPermission notificationPermission(Ref ref) =>
    const PlatformNotificationPermission();
