import 'package:app_pdf/providers/file_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android: the public Documents/Dokulo of the primary volume', () {
    expect(
      androidUserFolder('/storage/emulated/0/Android/data/app.dokulo/files')
          .path,
      '/storage/emulated/0/Documents/Dokulo',
    );
    expect(
      () => androidUserFolder('/data/user/0/app.dokulo'),
      throwsStateError,
    );
  });
}
