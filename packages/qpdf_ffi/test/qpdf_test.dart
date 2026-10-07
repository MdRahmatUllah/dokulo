import 'dart:io';

import 'package:qpdf_ffi/qpdf_ffi.dart';
import 'package:test/test.dart';

/// The shared fictional sample documents (DK-0023).
String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('dk_qpdf_test_'));
  tearDown(() => out.deleteSync(recursive: true));
  String outFile(String name) => '${out.path}/$name';

  final invoice = fixture('Invoice INV-2026-014.pdf');
  final long = fixture('long-300-pages.pdf');

  test(
    'inspect reads pages, version and flags, also with ß/ü/– in the name',
    () {
      final info = Qpdf.inspect(fixture('Mietvertrag Musterstraße 12.pdf'));
      expect(info.pages, 3);
      expect(info.encrypted, isFalse);
      expect(info.version, matches(RegExp(r'^\d\.\d$')));
      expect(
        Qpdf.inspect(fixture('Finanzamt München – Bescheid 2025.pdf')).pages,
        1,
      );
    },
  );

  test('encrypt with AES-256 and decrypt again', () {
    Qpdf.encrypt(invoice, outFile('locked.pdf'), userPassword: 'geheim');
    expect(
      () => Qpdf.inspect(outFile('locked.pdf')),
      throwsA(_kind(QpdfErrorKind.password)),
    );
    expect(
      Qpdf.inspect(outFile('locked.pdf'), password: 'geheim').encrypted,
      isTrue,
    );

    Qpdf.decrypt(
      outFile('locked.pdf'),
      outFile('open.pdf'),
      password: 'geheim',
    );
    final open = Qpdf.inspect(outFile('open.pdf'));
    expect((open.encrypted, open.pages), (false, 1));
  });

  test('the sample encrypted file opens with its password only', () {
    final encrypted = fixture('encrypted-aes256.pdf');
    expect(
      () => Qpdf.decrypt(encrypted, outFile('x.pdf'), password: 'wrong'),
      throwsA(_kind(QpdfErrorKind.password)),
    );
    expect(
      File(outFile('x.pdf')).existsSync(),
      isFalse,
      reason: 'no partial output',
    );
    Qpdf.decrypt(encrypted, outFile('x.pdf'), password: 'dokulo');
    expect(Qpdf.inspect(outFile('x.pdf')).encrypted, isFalse);
  });

  test('repair rebuilds a broken cross-reference table', () {
    final damaged = fixture('damaged-xref.pdf');
    final warnings = Qpdf.repair(damaged, outFile('fixed.pdf'));
    expect(warnings, isNotEmpty, reason: 'qpdf says what it fixed');
    expect(
      Qpdf.check(outFile('fixed.pdf')),
      isEmpty,
      reason: 'the result checks clean',
    );
    expect(Qpdf.inspect(outFile('fixed.pdf')).pages, 1);
  });

  test('a file that is not a PDF is reported as damaged', () {
    File(outFile('note.pdf')).writeAsStringSync('just text');
    expect(
      () => Qpdf.repair(outFile('note.pdf'), outFile('y.pdf')),
      throwsA(_kind(QpdfErrorKind.damaged)),
    );
    expect(
      () => Qpdf.inspect(outFile('note.pdf')),
      throwsA(_kind(QpdfErrorKind.damaged)),
    );
  });

  test('compress structure keeps every page and shrinks the file', () {
    Qpdf.compressStructure(long, outFile('small.pdf'));
    expect(Qpdf.inspect(outFile('small.pdf')).pages, 300);
    expect(
      File(outFile('small.pdf')).lengthSync(),
      lessThan(File(long).lengthSync()),
    );
  });

  test('linearize', () {
    Qpdf.linearize(invoice, outFile('web.pdf'));
    expect(Qpdf.inspect(outFile('web.pdf')).linearized, isTrue);
  });

  test('extract page ranges', () {
    Qpdf.extract(long, '1-3,7', outFile('part.pdf'));
    expect(Qpdf.inspect(outFile('part.pdf')).pages, 4);
    Qpdf.extract(long, 'z', outFile('last.pdf'));
    expect(Qpdf.inspect(outFile('last.pdf')).pages, 1);
  });

  test('overlay and underlay a stamp on every page', () {
    Qpdf.extract(long, '1-5', outFile('five.pdf'));
    Qpdf.overlay(
      outFile('five.pdf'),
      invoice,
      outFile('over.pdf'),
      repeat: '1',
    );
    Qpdf.overlay(
      outFile('five.pdf'),
      invoice,
      outFile('under.pdf'),
      underlay: true,
      repeat: '1',
    );
    for (final name in ['over.pdf', 'under.pdf']) {
      expect(Qpdf.inspect(outFile(name)).pages, 5);
      expect(
        File(outFile(name)).lengthSync(),
        greaterThan(File(outFile('five.pdf')).lengthSync()),
      );
    }
  });

  test('a bad job is a json error', () {
    expect(
      () => Qpdf.run({'inputFile': invoice, 'noSuchOption': ''}),
      throwsA(_kind(QpdfErrorKind.json)),
    );
  });
}

Matcher _kind(QpdfErrorKind kind) =>
    isA<QpdfException>().having((e) => e.kind, 'kind', kind);
