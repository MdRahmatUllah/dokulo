/// What a detector found (Technology plan, "Redaction auto-detect").
/// [personName] and [address] come only from the AI suggestions (DK-0520).
enum SensitiveKind {
  iban,
  taxId,
  email,
  phone,
  ssn,
  niNumber,
  dateOfBirth,
  personName,
  address,
}

/// A sensitive span of a page's text. The review sheet shows every finding;
/// [verified] means its check digits hold (an IBAN, a Steuer-ID), so it can
/// be preselected with confidence.
class Finding {
  const Finding(
    this.kind,
    this.start,
    this.end,
    this.text, {
    this.verified = false,
  });
  final SensitiveKind kind;

  /// Character offsets into the text the detector ran on.
  final int start, end;
  final String text;
  final bool verified;

  @override
  String toString() => '${kind.name}${verified ? '✓' : ''}: $text';
}

/// The redaction detectors (DK-0393): regular expressions, checked with
/// check digits where the format has them. Findings never overlap; the
/// earlier and longer one wins. An optional Gemma pass for names and
/// addresses (DK-0548) adds to these; the user reviews all of them.
List<Finding> findSensitive(String text) {
  final found =
      <Finding>[
        for (final m in _iban.allMatches(text))
          Finding(
            SensitiveKind.iban,
            m.start,
            m.end,
            m[0]!,
            verified: ibanValid(m[0]!),
          ),
        for (final m in _email.allMatches(text))
          Finding(SensitiveKind.email, m.start, m.end, m[0]!),
        for (final m in _taxId.allMatches(text))
          if (taxIdValid(m[0]!))
            Finding(SensitiveKind.taxId, m.start, m.end, m[0]!, verified: true),
        for (final m in _ssn.allMatches(text))
          Finding(SensitiveKind.ssn, m.start, m.end, m[0]!),
        for (final m in _ni.allMatches(text))
          Finding(SensitiveKind.niNumber, m.start, m.end, m[0]!),
        for (final m in _phone.allMatches(text))
          if (_digits(m[0]!).length >= 7 && _digits(m[0]!).length <= 15)
            Finding(SensitiveKind.phone, m.start, m.end, m[0]!.trim()),
        for (final m in _birth.allMatches(text))
          Finding(
            SensitiveKind.dateOfBirth,
            m.start + m[0]!.indexOf(m[1]!),
            m.start + m[0]!.indexOf(m[1]!) + m[1]!.length,
            m[1]!,
          ),
      ]..sort(
        (a, b) => a.start != b.start
            ? a.start.compareTo(b.start)
            : b.end.compareTo(a.end),
      );
  final out = <Finding>[];
  for (final f in found) {
    if (out.isEmpty || f.start >= out.last.end) out.add(f);
  }
  return out;
}

String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

/// An IBAN, with or without spaces in groups of four.
final _iban = RegExp(
  r'\b[A-Z]{2}\d{2}(?: ?[A-Z0-9]{4}){2,7}(?: ?[A-Z0-9]{1,3})?\b',
);

/// ISO 13616 mod 97 == 1.
bool ibanValid(String iban) {
  final s = iban.replaceAll(' ', '');
  if (s.length < 15 || s.length > 34) return false;
  final moved = s.substring(4) + s.substring(0, 4);
  var rest = 0;
  for (final c in moved.codeUnits) {
    final value = c <= 57 ? c - 48 : c - 55; // 0-9, A=10 … Z=35
    rest = (value > 9 ? rest * 100 + value : rest * 10 + value) % 97;
  }
  return rest == 1;
}

/// The German Steuer-ID: 11 digits, often as "12 345 678 901".
final _taxId = RegExp(r'\b\d{2} ?\d{3} ?\d{3} ?\d{3}\b');

/// Steuer-ID rules: no leading zero; among the first ten digits one digit
/// appears twice (or three times), at least one doesn't appear; the last
/// digit is the ISO 7064 MOD 11,10 check digit.
bool taxIdValid(String id) {
  final d = _digits(id);
  if (d.length != 11 || d[0] == '0') return false;
  final counts = <String, int>{};
  for (final c in d.substring(0, 10).split('')) {
    counts[c] = (counts[c] ?? 0) + 1;
  }
  final repeated = counts.values.where((n) => n > 1).toList();
  if (repeated.length != 1 || repeated.single > 3) return false;
  var product = 10;
  for (var i = 0; i < 10; i++) {
    var sum = (int.parse(d[i]) + product) % 10;
    if (sum == 0) sum = 10;
    product = (sum * 2) % 11;
  }
  final check = (11 - product) % 10;
  return check == int.parse(d[10]);
}

final _email = RegExp(r"[A-Za-z0-9._%+'-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}");

/// US SSN: not 000, 666 or 9xx in the area, no all-zero group or serial.
final _ssn = RegExp(r'\b(?!000|666|9\d\d)\d{3}-(?!00)\d{2}-(?!0000)\d{4}\b');

/// UK National Insurance number.
final _ni = RegExp(
  r'\b(?!BG|GB|NK|KN|TN|NT|ZZ)[A-CEGHJ-PR-TW-Z][A-CEGHJ-NPR-TW-Z] ?\d{2} ?\d{2} ?\d{2} ?[A-D]\b',
);

/// A phone number: international (+49 …, 0049 …) or national, a 0 then the
/// area code (089 0000000, 0171/1234567); never 0 then 0 then a non-digit. ponytail: a pattern, not a numbering plan;
/// phone_numbers_parser (docs/versions.md) if false positives show up.
final _phone = RegExp(
  r'(?<![\w+])(?:\+[1-9]\d{0,2}[ /-]?(?:\(0\)[ /-]?)?\d|00[1-9]|0[1-9])[\d /-]{5,16}\d(?!\w)',
);

/// A date right after a birth keyword (geboren am, born, Geburtsdatum, DOB).
final _birth = RegExp(
  r'(?:geboren(?: am)?|geb\.|Geburtsdatum:?|born(?: on)?|date of birth:?|DOB:?)\s+'
  r'(\d{1,2}\.\s?\d{1,2}\.\s?\d{2,4}|\d{1,2}\.? [A-Za-zäÄ]+ \d{4}|[A-Za-z]+ \d{1,2},? \d{4}|\d{4}-\d{2}-\d{2})',
  caseSensitive: false,
);

/// The finding as Black out's review lists it (DK-0520): enough to know it
/// again, not to read it. An IBAN keeps its country, check digits and last
/// four ("DE89 •••• •••• •••• 3000"); an email its first letter and domain
/// ("m•••@example.com"); a suggested name or address its first letter of
/// each word; everything else its last two characters, separators kept.
String maskedPreview(SensitiveKind kind, String text) {
  const dot = '•';
  switch (kind) {
    case SensitiveKind.iban:
      final s = text.replaceAll(' ', '');
      if (s.length < 9) return dot * s.length;
      final groups = (s.length - 8) ~/ 4;
      return [
        s.substring(0, 4),
        for (var i = 0; i < groups; i++) dot * 4,
        s.substring(s.length - 4),
      ].join(' ');
    case SensitiveKind.email:
      final at = text.indexOf('@');
      if (at < 1) return dot * text.length;
      return '${text[0]}${dot * 3}${text.substring(at)}';
    case SensitiveKind.personName || SensitiveKind.address:
      return text
          .split(' ')
          .map((w) => w.isEmpty ? w : '${w[0]}${dot * (w.length - 1)}')
          .join(' ');
    case _:
      final keep = text.length - 2;
      return String.fromCharCodes([
        for (var i = 0; i < text.length; i++)
          i < keep && RegExp(r'[A-Za-z0-9]').hasMatch(text[i])
              ? dot.codeUnitAt(0)
              : text.codeUnitAt(i),
      ]);
  }
}
