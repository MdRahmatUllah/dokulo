import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../crash/crash_log.dart';
import 'device_providers.dart';
import 'mail_providers.dart';
import 'prefs_providers.dart';

part 'crash_providers.g.dart';

/// The prefs key of "Keep crash reports".
const crashReportsKey = 'privacy.crashReports';

/// Settings → Privacy → "Keep crash reports" (DK-0011, DK-0576), kept in
/// [Prefs]. Off by default: the user turns it on. Kept alive: the error
/// hooks read it on every crash.
@Riverpod(keepAlive: true)
class CrashReportsEnabled extends _$CrashReportsEnabled {
  @override
  bool build() => ref.watch(prefsProvider).value?[crashReportsKey] == true;

  void set(bool on) {
    state = on;
    unawaited(ref.read(prefsProvider.notifier).set(crashReportsKey, on));
  }
}

/// The local crash log in app support. Tests override it with a temp file.
@Riverpod(keepAlive: true)
Future<CrashLog> crashLog(Ref ref) async => CrashLog(
  File(
    '${(await getApplicationSupportDirectory()).path}'
    '${Platform.pathSeparator}crash_log.jsonl',
  ),
);

/// "Send report by email" (DK-1080, DK-0011): a draft in the user's mail
/// app with the [code], the device facts and the local crash log, nothing
/// else; the user sends it or not. False when no mail app took it.
Future<bool> sendCrashReport(WidgetRef ref, {String? code}) async {
  final device = await ref.read(deviceCapabilitiesProvider.future);
  final entries = await (await ref.read(crashLogProvider.future)).entries();
  return ref.read(mailComposerProvider)(
    reportEmail(
      code: code,
      device: {
        'os': '${device.os} ${device.osVersion}',
        'abis': device.abis.join(', '),
        if (device.totalRam case final ram?)
          'ram': '${(ram / 1e9).toStringAsFixed(1)} GB',
      },
      entries: entries,
    ),
  );
}

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
