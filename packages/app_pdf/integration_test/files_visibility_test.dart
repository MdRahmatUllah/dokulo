// DK-1043, the device half of DK-0006: a saved tool output lands in the
// public Documents/Dokulo folder (where the Files app shows it), and a file
// deleted outside the app leaves the index on the next refresh. The host
// steers it with adb (docs/qa/device-lab.md):
//   python tools/device_checks/files_visibility.py emulator-5556 runs these:
//   1. flutter test integration_test/files_visibility_test.dart -d emulator-5556 --flavor dev
//   2. when "DEVICE | DK-1043 | saved | <path>" prints: check the file with
//      `adb shell ls` and MediaStore (`content query`), then `adb shell rm` it
//      (what deleting it in the Files app does);
//   3. the test sees it gone, reconciles, and checks the row is dropped.

import 'package:app_pdf/providers/file_providers.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdf/widgets.dart' as pw;

void report(String what, Object value) =>
    debugPrint('DEVICE | DK-1043 | $what | $value');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a saved output is in Documents/Dokulo; deleted outside, the '
      'index drops it', (tester) async {
    await tester.runAsync(() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final store = await container.read(fileStoreProvider.future);
      final db = DokuloDatabase.memory();
      addTearDown(db.close);

      final doc = pw.Document()
        ..addPage(pw.Page(build: (_) => pw.Text('DK-1043')));
      final output = await store.newTempFile('dk-1043-check.pdf');
      await output.writeAsBytes(await doc.save());
      final saved = await store.save(output, name: 'dk-1043-check.pdf');
      await store.reconcile(db);
      final rows = await db.select(db.files).get();
      expect(rows.map((r) => r.path), contains(saved.path));
      report('saved', saved.path);

      // The host checks it and deletes it outside the app (step 2).
      final deadline = DateTime.now().add(const Duration(minutes: 3));
      while (saved.existsSync() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(saved.existsSync(), isFalse, reason: 'deleted by the host');
      await store.reconcile(db);
      final after = await db.select(db.files).get();
      expect(after.map((r) => r.path), isNot(contains(saved.path)));
      report('deleted outside, after refresh', 'dropped from the index');
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
