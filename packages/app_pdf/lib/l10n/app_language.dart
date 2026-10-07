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

/// The chosen language. MaterialApp listens to it, so a change applies to
/// every screen at once, without a restart.
// ponytail: a ValueNotifier until DK-0003 brings Riverpod; persisting the
// choice belongs to the Settings screen task.
class AppLanguageController extends ValueNotifier<AppLanguage> {
  AppLanguageController([super.value = AppLanguage.system]);
}
