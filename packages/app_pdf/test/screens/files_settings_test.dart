import 'dart:io';

import 'package:app_pdf/l10n/formats.dart';
import 'package:app_pdf/providers/files_providers.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/screens/settings/files_settings_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'files_screen_test.dart' show FilesFixture, pumpFiles, settle;

/// M3 · Files & storage (DK-0572) and the storage bar (DK-0281).
void main() {
  late FilesFixture f;
  setUp(() async {
    f = FilesFixture();
    await f.setUp();
  });
  tearDown(() => f.tearDown());

  testWidgets('Keep deleted files: 30 days by default, 7 from the menu', (
    tester,
  ) async {
    await pumpFiles(tester, f, location: Routes.settings('files'));
    expect(find.text('30 days'), findsOneWidget);
    await tester.tap(find.text('Keep deleted files'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    expect(find.text('7 days'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FilesSettingsScreen)),
    );
    expect(container.read(trashRetentionDaysProvider), 7);
  });

  testWidgets('the storage bar: files, models, cache; Clear cache', (
    tester,
  ) async {
    await tester.runAsync(() async {
      File('${f.root.path}/Dokulo/a.pdf')
        ..createSync(recursive: true)
        ..writeAsBytesSync(List.filled(3000, 1));
      File('${f.root.path}/work/temp/t.bin')
        ..createSync(recursive: true)
        ..writeAsBytesSync(List.filled(500, 1))
        ..setLastModifiedSync(DateTime.now().subtract(const Duration(days: 2)));
    });
    await pumpFiles(tester, f, location: Routes.settings('files'));
    // Walking the folders is real disk work.
    for (var i = 0; i < 4; i++) {
      await settle(tester);
    }
    expect(find.text(formatBytes(3000, 'en')), findsOneWidget);
    expect(find.text(formatBytes(500, 'en')), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Clear cache'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    for (var i = 0; i < 3; i++) {
      await settle(tester);
    }
    expect(find.text('Cache cleared'), findsOneWidget);
    expect(File('${f.root.path}/work/temp/t.bin').existsSync(), isFalse);
    expect(File('${f.root.path}/Dokulo/a.pdf').existsSync(), isTrue);
  });

  test('Clear cache: thumbnails and old temp files; not a fresh result, '
      'not while a job runs, never the inbox', () async {
    final work = Directory('${f.root.path}/cc')..createSync();
    final thumbs = Directory('${work.path}/thumbs')..createSync();
    File('${thumbs.path}/p.png').writeAsStringSync('x');
    final temp = Directory('${work.path}/temp')..createSync();
    final now = DateTime.now();
    final old = File('${temp.path}/old.pdf')
      ..writeAsStringSync('x')
      ..setLastModifiedSync(now.subtract(const Duration(days: 2)));
    final fresh = File('${temp.path}/result.pdf')..writeAsStringSync('x');
    final inbox = File('${work.path}/inbox/in.pdf')
      ..createSync(recursive: true)
      ..writeAsStringSync('x');

    await clearCache(thumbs, temp, jobsRunning: true, now: now);
    expect(thumbs.existsSync(), isFalse);
    expect(old.existsSync(), isTrue, reason: 'a job is running');

    await clearCache(thumbs, temp, jobsRunning: false, now: now);
    expect(old.existsSync(), isFalse);
    expect(fresh.existsSync(), isTrue);
    expect(temp.existsSync(), isTrue);
    expect(inbox.existsSync(), isTrue);
  });
}
