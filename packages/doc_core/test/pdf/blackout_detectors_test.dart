import 'package:doc_core/doc_core.dart';
import 'package:test/test.dart';

Box at(double left, double bottom, {double width = 40}) =>
    (left: left, top: bottom + 12, right: left + width, bottom: bottom);

void main() {
  group('checksums (valid and invalid samples)', () {
    test('IBAN mod 97', () {
      expect(ibanValid('DE89 3704 0044 0532 0130 00'), isTrue);
      expect(ibanValid('GB82 WEST 1234 5698 7654 32'), isTrue);
      expect(ibanValid('DE89 3704 0044 0532 0130 01'), isFalse);
      expect(ibanValid('DE00 0000'), isFalse);
    });

    test('Steuer-ID check digit', () {
      expect(taxIdValid('86095742719'), isTrue);
      expect(taxIdValid('86 095 742 719'), isTrue);
      expect(taxIdValid('86095742718'), isFalse, reason: 'wrong check digit');
      expect(taxIdValid('01234567890'), isFalse, reason: 'leading zero');
    });

    test(
      'only a verified Steuer-ID is a finding; an IBAN says if it holds',
      () {
        final found = findSensitive(
          'Steuer-ID 86095742719, falsch 86095742718. '
          'IBAN DE89 3704 0044 0532 0130 00 und DE89 3704 0044 0532 0130 01.',
        );
        expect(
          [for (final f in found) (f.kind, f.verified)],
          [
            (SensitiveKind.taxId, true),
            (SensitiveKind.iban, true),
            (SensitiveKind.iban, false),
          ],
        );
      },
    );

    test('SSN, UK NI, email, phone, date of birth', () {
      final kinds = {
        for (final f in findSensitive(
          'SSN 123-45-6789, not 000-12-3456. NI AB 12 34 56 C. '
          'max@example.com, +49 89 1234567, geboren am 12.03.1985',
        ))
          f.kind,
      };
      expect(kinds, {
        SensitiveKind.ssn,
        SensitiveKind.niNumber,
        SensitiveKind.email,
        SensitiveKind.phone,
        SensitiveKind.dateOfBirth,
      });
    });
  });

  group('maskedPreview', () {
    test('IBAN: country, check digits and the last four', () {
      expect(
        maskedPreview(SensitiveKind.iban, 'DE89 3704 0044 0532 0130 00'),
        'DE89 •••• •••• •••• 3000',
      );
    });
    test('email: first letter and domain', () {
      expect(
        maskedPreview(SensitiveKind.email, 'max@example.com'),
        'm•••@example.com',
      );
    });
    test('others: the last two, separators kept', () {
      expect(maskedPreview(SensitiveKind.ssn, '123-45-6789'), '•••-••-••89');
      expect(
        maskedPreview(SensitiveKind.personName, 'Max Mustermann'),
        'M•• M•••••••••',
      );
    });
  });

  test('a scan after OCR: findings boxed by their words, one per line', () {
    final boxes = PdfRedactor.findInWords(2, [
      ('IBAN', at(10, 700)),
      ('DE89', at(60, 700)),
      ('3704', at(110, 700)),
      ('0044', at(160, 700)),
      ('0532', at(10, 680)),
      ('0130', at(60, 680)),
      ('00', at(110, 680, width: 20)),
    ]);
    expect(boxes, hasLength(2), reason: 'the IBAN spans two lines');
    expect(
      boxes.every((b) => b.page == 2 && b.kind == SensitiveKind.iban),
      isTrue,
    );
    expect(boxes.first.box.left, 60);
    expect(boxes.first.box.right, 200);
    expect(boxes.last.box.right, 130);
    expect(boxes.first.preview, 'DE89 •••• •••• •••• 3000');
  });

  test(
    'AI suggestions are marked suggested (never checked for the user)',
    () async {
      const text =
          'Mieter: Max Mustermann, Musterstraße 12. Max Mustermann zahlt.';
      final chars = [
        for (var i = 0; i < text.length; i++) at(i * 6.0, 700, width: 6),
      ];
      final boxes = await PdfRedactor.suggest(
        0,
        text,
        chars,
        (_) async => [
          (SensitiveKind.personName, 'Max Mustermann'),
          (SensitiveKind.address, 'Musterstraße 12'),
          (SensitiveKind.personName, '  '),
        ],
      );
      expect(boxes, hasLength(3), reason: 'the name twice, the address once');
      expect(boxes.every((b) => b.suggested), isTrue);
      expect(boxes.map((b) => b.kind).toSet(), {
        SensitiveKind.personName,
        SensitiveKind.address,
      });
    },
  );
}
