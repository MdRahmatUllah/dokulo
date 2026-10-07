import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../crash/crash_log.dart';

part 'crash_providers.g.dart';

/// Settings → Privacy → "Keep crash reports" (DK-0011). Off by default: the
/// user turns it on. Kept alive: the error hooks read it on every crash.
/// M3 persists it.
@Riverpod(keepAlive: true)
class CrashReportsEnabled extends _$CrashReportsEnabled {
  @override
  bool build() => false;

  void set(bool on) => state = on;
}

/// The local crash log in app support. Tests override it with a temp file.
@Riverpod(keepAlive: true)
Future<CrashLog> crashLog(Ref ref) async => CrashLog(
  File(
    '${(await getApplicationSupportDirectory()).path}'
    '${Platform.pathSeparator}crash_log.jsonl',
  ),
);

/// Sends uncaught Flutter and platform errors to the crash log while the user
/// has crash reports on; with them off, nothing is written. Flutter's own
/// reporting (the console in debug builds) keeps working either way.
void installCrashHooks(ProviderContainer container) {
  Future<void> record(Object error, StackTrace? stack) async {
    if (!container.read(crashReportsEnabledProvider)) return;
    final log = await container.read(crashLogProvider.future);
    await log.record(CrashEntry.of(error, stack));
  }

  final flutterHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    record(details.exception, details.stack);
    flutterHandler?.call(details);
  };
  final platformHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    record(error, stack);
    return platformHandler?.call(error, stack) ?? false;
  };
}
