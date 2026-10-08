// DK-1048, the device half of DK-0018: on a 16 KB-page system image the app
// starts, its native libraries load, and the viewer opens
// test/fixtures/Invoice INV-2026-014.pdf. The device can't read the repo, so
// the host copies the fixture into the app's folder when the test asks:
//   python tools/device_checks/page_size.py emulator-5560
import 'dart:io';

import 'package:app_pdf/components/dk_pdf_canvas.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

void report(String what, Object value) =>
    debugPrint('DEVICE | DK-1048 | $what | $value');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the viewer opens the invoice on this device', (tester) async {
    await pdfrxFlutterInitialize();
    final invoice = await tester.runAsync(() async {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/invoice.pdf');
      if (file.existsSync()) file.deleteSync();
      report('waiting', file.path);
      final deadline = DateTime.now().add(const Duration(minutes: 2));
      while (!file.existsSync() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      await Future<void>.delayed(const Duration(seconds: 1)); // fully copied
      return file;
    });
    expect(invoice!.existsSync(), isTrue, reason: 'the host copies it');

    final info = (await tester.runAsync(
      () => PdfEngine.inspect(invoice.path),
    ))!;
    report('pages', info.pageCount);
    final controller = PdfViewerController();
    await tester.pumpWidget(
      MaterialApp(
        theme: dokuloTheme(DkTokens.light),
        home: Scaffold(
          body: DkPdfCanvas(path: invoice.path, controller: controller),
        ),
      ),
    );
    for (var i = 0; i < 50 && !controller.isReady; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(controller.isReady, isTrue, reason: 'the viewer loaded it');
    expect(controller.pageCount, info.pageCount);
    report('viewer', 'open, ${controller.pageCount} page(s)');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
