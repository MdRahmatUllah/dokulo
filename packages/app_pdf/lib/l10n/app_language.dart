import 'package:flutter/widgets.dart';

/// Settings → Language: System · English · Deutsch (UI spec §25).
enum AppLanguage {
  system(null),
  english(Locale('en')),
  deutsch(Locale('de'));

  const AppLanguage(this.locale);

  /// The locale to force, or null to follow the system.
  final Locale? locale;
}
