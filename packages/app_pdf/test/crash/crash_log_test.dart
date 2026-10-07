import 'dart:convert';
import 'dart:io';

import 'package:app_pdf/crash/crash_log.dart';
import 'package:app_pdf/providers/crash_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A crash the way a tool could throw one: the message names the user's file
/// and quotes the document.
final leaky = StateError(
  'Cannot read /storage/emulated/0/Documents/Dokulo/Mietvertrag Musterstraße 12.pdf: '
  'unexpected "Die monatliche Grundmiete beträgt 1.240,00 EUR" on page 2',
);

final stack = StackTrace.fromString(
  '#0      PdfEngine.text (package:doc_core/src/pdf/engine.dart:120:7)\n'
  '#1      main.<anonymous closure> (file:///C:/Users/someone/dokulo/packages/app_pdf/test/x.dart:9:5)\n'
  '#2      _rootRun (dart:async/zone.dart:1399:13)\n',
);

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('dk_crash_'));
  tearDown(() async => dir.delete(recursive: true));

  test('an entry keeps no file name, path or document text', () {
    final entry = CrashEntry.of(leaky, stack, code: 'DK-0142');
    final json = jsonEncode(entry.toJson());
    for (final secret in [
      'Mietvertrag',
      'Musterstraße',
      '.pdf',
      'Grundmiete',
      '1.240',
      'someone',
      'Documents',
    ]) {
      expect(json, isNot(contains(secret)), reason: secret);
    }
    expect(entry.type, 'StateError');
    expect(entry.code, 'DK-0142');
    expect(entry.frames, [
      '#0      PdfEngine.text (package:doc_core/src/pdf/engine.dart:120:7)',
      '#1      main.<anonymous closure> (<path>',
      '#2      _rootRun (dart:async/zone.dart:1399:13)',
    ]);
  });

  test('the log keeps the newest entries and can be cleared', () async {
    final log = CrashLog(File('${dir.path}/crash_log.jsonl'), keep: 3);
    expect(await log.entries(), isEmpty);
    for (var i = 0; i < 5; i++) {
      await log.record(CrashEntry.of(leaky, stack, code: 'DK-000$i'));
    }
    expect(
      [for (final e in await log.entries()) e.code],
      ['DK-0002', 'DK-0003', 'DK-0004'],
    );
    await log.clear();
    expect(await log.entries(), isEmpty);
  });

  test('the email carries the code, the device facts and the log only', () {
    final email = reportEmail(
      code: 'DK-0142',
      device: {'OS': 'android 14', 'Memory': '8 GB'},
      entries: [CrashEntry.of(leaky, stack, code: 'DK-0142')],
    );
    expect(email.scheme, 'mailto');
    final text = Uri.decodeComponent(email.query);
    expect(text, contains('subject=Dokulo report DK-0142'));
    expect(text, contains('OS: android 14'));
    expect(text, contains('package:doc_core/src/pdf/engine.dart:120:7'));
    expect(text, isNot(contains('Mietvertrag')));
    expect(email.query, isNot(contains('+')));
  });

  group('the error hooks', () {
    late FlutterExceptionHandler? previous;
    setUp(() {
      previous = FlutterError.onError;
      FlutterError.onError = (
        _,
      ) {}; // keep the test framework's handler out of it
    });
    tearDown(() => FlutterError.onError = previous);

    Future<List<CrashEntry>> crashWith({required bool enabled}) async {
      final log = CrashLog(File('${dir.path}/hooks.jsonl'));
      final container = ProviderContainer(
        overrides: [crashLogProvider.overrideWith((ref) async => log)],
      );
      addTearDown(container.dispose);
      container.read(crashReportsEnabledProvider.notifier).set(enabled);
      installCrashHooks(container);
      FlutterError.onError!(
        FlutterErrorDetails(exception: leaky, stack: stack),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return log.entries();
    }

    test('write nothing while crash reports are off (the default)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(crashReportsEnabledProvider), isFalse);
      expect(await crashWith(enabled: false), isEmpty);
    });

    test('record a crash once the user turns them on', () async {
      final entries = await crashWith(enabled: true);
      expect(entries.single.type, 'StateError');
    });
  });
}
