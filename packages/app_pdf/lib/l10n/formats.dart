import 'package:intl/intl.dart';

/// Narrow no-break space between a number and its unit: the "thin space" of the
/// copy rules (docs/Overview & foundations.md) that never wraps the unit away.
const unitSpace = ' ';

/// File sizes in decimal units, as iOS and Android show them: "1.9 MB" / "1,9 MB".
/// One decimal below 10, none from 10 up ("32 MB", "440 MB", "1.8 GB").
String formatBytes(int bytes, String locale) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 999.5 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  final digits = unit > 0 && value < 9.95 ? 1 : 0;
  final number =
      (NumberFormat.decimalPattern(locale)
            ..minimumFractionDigits = 0
            ..maximumFractionDigits = digits)
          .format(value);
  return '$number$unitSpace${units[unit]}';
}

/// A calendar date: "7 Oct 2026" / "7. Okt. 2026".
String formatDate(DateTime date, String locale) => locale.startsWith('de')
    ? DateFormat.yMMMd(locale).format(date)
    : DateFormat('d MMM y', locale).format(date);
