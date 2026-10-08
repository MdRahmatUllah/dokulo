// DK-1047, the device half of DK-0021: the app is killed mid-Compress and
// relaunched. Three launches of this test, steered by the host with adb
// (python tools/device_checks/kill_recovery.py emulator-5556; docs/qa/device-lab.md):
//   1. no marker: a scan goes into Documents/Dokulo, Compress starts, and
//      "DEVICE | DK-1047 | started" prints; the host force-stops the app.
//   2. marker 1: the launch cleanup resumes the job, which finishes with a
//      complete file; nothing partial is in Documents/Dokulo, temp holds only
//      that output. A second Compress starts; the host force-stops the app
//      and deletes that job's input.
//   3. marker 2: the launch reports the job as "Couldn't finish"; clean up.
import 'dart:io';
import 'dart:math';

import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/file_providers.dart';
import 'package:app_pdf/providers/job_providers.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

void report(String what, Object value) =>
    debugPrint('DEVICE | DK-1047 | $what | $value');

/// A 300 dpi grey scan of [pages] distinct pages, so Compress has work.
Future<void> scan(String path, int pages) async {
  final doc = pw.Document();
  for (var p = 0; p < pages; p++) {
    final page = img.Image(width: 2480, height: 3508, numChannels: 1);
    final random = Random(p);
    for (final px in page) {
      px.r = 235 + random.nextInt(20);
    }
    final image = pw.MemoryImage(img.encodeJpg(page, quality: 85));
    doc.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
      ),
    );
  }
  await File(path).writeAsBytes(await doc.save());
}

const pages = 12;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DK-1047: killed mid-Compress, the app recovers', (tester) async {
    await tester.runAsync(() async {
      await pdfrxFlutterInitialize();
      final container = ProviderContainer();
      final files = await container.read(fileStoreProvider.future);
      final marker = File('${files.workDirectory.path}/dk-1047.phase');
      final phase = marker.existsSync() ? marker.readAsStringSync() : '0';
      report('phase', phase);
      final user = files.userFolder..createSync(recursive: true);
      final first = '${user.path}/dk-1047-input.pdf';
      final second = '${user.path}/dk-1047-input-2.pdf';

      Future<void> startCompress(String input, String next) async {
        final queue = await container.read(jobQueueProvider.future);
        final run = await queue.start(
          'compress',
          CompressInput(
            files: [input],
            outputDir: files.temp.path,
            suffix: ' – compressed',
          ),
        );
        marker.writeAsStringSync(next);
        await run.progress.first;
        report('started', input);
        // The host kills the app now; if it doesn't, this fails.
        await run.result;
        fail('the job finished before the host killed the app');
      }

      switch (phase) {
        case '0':
          await files.temp.create(recursive: true);
          await scan(first, pages);
          await startCompress(first, '1');
        case '1':
          final report1 = await container.read(startupProvider.future);
          expect(report1.resumed, hasLength(1), reason: 'the killed job');
          final output = await report1.resumed.single.result as OneFile;
          final info = await PdfEngine.inspect(output.path);
          expect(info.pageCount, pages, reason: 'a complete file');
          final inUser = user.listSync().map((e) => e.path).toList();
          expect(inUser, [
            first,
          ], reason: 'nothing partial in Documents/Dokulo');
          final inTemp = files.temp.listSync().map((e) => e.path).toList();
          expect(inTemp, [output.path], reason: 'temp holds only the output');
          report('resumed', '${info.pageCount} pages, nothing partial');
          File(output.path).deleteSync();
          File(first).copySync(second);
          await startCompress(second, '2');
        case '2':
          final report2 = await container.read(startupProvider.future);
          expect(report2.resumed, isEmpty);
          expect(report2.couldNotFinish.map((j) => j.toolId), [
            'compress',
          ], reason: "Home's \"Couldn't finish Compress\"");
          report('input deleted', "couldn't finish: compress");
          final queue = await container.read(jobQueueProvider.future);
          for (final job in report2.couldNotFinish) {
            await queue.forget(job);
          }
          for (final path in [first, second]) {
            if (File(path).existsSync()) File(path).deleteSync();
          }
          marker.deleteSync();
          await container.read(appDatabaseProvider).close();
          report('done', 'cleaned up');
      }
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
