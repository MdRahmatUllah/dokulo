import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/l10n/formats.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Locale formats (DK-0634) in de_DE, en_US and en_GB: decimal comma, the
/// thin space before units, dates, 24 h times, A4 or Letter.
void main() {
  setUpAll(() async {
    for (final l in ['de_DE', 'en_US', 'en_GB']) {
      await initializeDateFormatting(l);
    }
  });

  final day = DateTime(2026, 10, 7, 14, 32);

  test('sizes: a decimal comma in German, a point in English', () {
    expect(formatBytes(1900000, 'de_DE'), '1,9${unitSpace}MB');
    expect(formatBytes(1900000, 'en_US'), '1.9${unitSpace}MB');
    expect(formatBytes(1900000, 'en_GB'), '1.9${unitSpace}MB');
  });

  test('dates', () {
    expect(formatDate(day, 'de_DE'), '7. Okt. 2026');
    expect(formatDate(day, 'en_US'), '7 Oct 2026');
    expect(formatDate(day, 'en_GB'), '7 Oct 2026');
  });

  test('a time in a meta line is 24 h in every locale', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    for (final l in ['de_DE', 'en_US', 'en_GB']) {
      expect(
        formatWhen(day, en, l, now: DateTime(2026, 10, 7, 20)),
        'Today 14:32',
        reason: l,
      );
    }
  });

  test('A4 except in the US and Canada', () {
    expect(usesLetter(const Locale('en', 'US')), isTrue);
    expect(usesLetter(const Locale('fr', 'CA')), isTrue);
    expect(usesLetter(const Locale('en', 'GB')), isFalse);
    expect(usesLetter(const Locale('de', 'DE')), isFalse);
    expect(usesLetter(const Locale('en')), isFalse);
  });
}
