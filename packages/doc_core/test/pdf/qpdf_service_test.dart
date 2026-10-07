import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:qpdf_ffi/qpdf_ffi.dart';
import 'package:test/test.dart';

/// The fictional sample invoice (DK-0023).
final _invoice =
    '${Directory.current.path}/../../test/fixtures/Invoice INV-2026-014.pdf';

int _pages(String path, JobContext context) =>
    QpdfService.run(() => Qpdf.inspect(path).pages);

int _wrongPassword(String path, JobContext context) =>
    QpdfService.run(() => Qpdf.inspect(path, password: 'wrong').pages);

void main() {
  late Directory temp;
  late IsolatePool pool;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('dk_qpdf_service_');
    pool = IsolatePool(tempRoot: temp);
  });
  tearDown(() => temp.deleteSync(recursive: true));

  test('runs on a qpdf worker and never on this isolate', () async {
    expect(await pool.run(Lane.qpdf, _pages, _invoice).result, 1);
    expect(() => QpdfService.run(() => 1), throwsA(isA<AssertionError>()));
  });

  test("qpdf's errors arrive as the catalogue's", () async {
    final encrypted =
        '${Directory.current.path}/../../test/fixtures/encrypted-aes256.pdf';
    await expectLater(
      pool.run(Lane.qpdf, _wrongPassword, encrypted).result,
      throwsA(
        isA<JobFailed>().having(
          (e) => e.message,
          'message',
          contains('DocError(locked'),
        ),
      ),
    );
    for (final (kind, message, expected) in [
      (QpdfErrorKind.password, 'invalid password', DocErrorKind.locked),
      (QpdfErrorKind.damaged, 'unable to find trailer', DocErrorKind.damaged),
      (QpdfErrorKind.pages, 'bad pages tree', DocErrorKind.damaged),
      (
        QpdfErrorKind.system,
        'write: No space left on device',
        DocErrorKind.notEnoughStorage,
      ),
      (QpdfErrorKind.internal, 'logic error', DocErrorKind.unexpected),
    ]) {
      expect(
        QpdfService.docErrorOf(QpdfException(kind, message)).kind,
        expected,
        reason: message,
      );
    }
  });
}
