// qpdf on a device (DK-0391): the native library loads on this ABI and runs
// inside a Lane.qpdf job, as the tools will use it. Run it on the shared
// emulator under `team.py device`:
//   flutter test integration_test/qpdf_test.dart -d emulator-5554 --flavor dev
import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qpdf_ffi/qpdf_ffi.dart';

/// A one-page PDF with no valid cross-reference table: qpdf rebuilds it.
const _tinyPdf =
    '%PDF-1.7\n'
    '1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n'
    '2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n'
    '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] >> endobj\n'
    'trailer << /Root 1 0 R >>\n%%EOF\n';

/// Repair, encrypt, decrypt; returns (pages, encrypted after decrypt).
(int, bool) _roundTrip(String dir, JobContext context) => QpdfService.run(() {
  File('$dir/in.pdf').writeAsStringSync(_tinyPdf);
  Qpdf.repair('$dir/in.pdf', '$dir/fixed.pdf');
  Qpdf.encrypt('$dir/fixed.pdf', '$dir/locked.pdf', userPassword: 'geheim');
  Qpdf.decrypt('$dir/locked.pdf', '$dir/open.pdf', password: 'geheim');
  final info = Qpdf.inspect('$dir/open.pdf');
  return (info.pages, info.encrypted);
});

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('qpdf repairs, encrypts and decrypts on this device', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('dk_qpdf_');
    final pool = IsolatePool(tempRoot: dir);
    final (pages, encrypted) =
        await tester.runAsync(
          () => pool.run(Lane.qpdf, _roundTrip, dir.path).result,
        ) ??
        (0, true);
    expect((pages, encrypted), (1, false));
    dir.deleteSync(recursive: true);
  });
}
