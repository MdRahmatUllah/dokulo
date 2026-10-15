import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../l10n/app_language.dart';
import 'prefs_providers.dart';

part 'language_providers.g.dart';

/// The prefs key of the app language (an [AppLanguage] name).
const appLanguageKey = 'app.language';

/// System, English or Deutsch (Me → Settings → Language, DK-0575), kept in
/// [Prefs] so it outlives a restart. Kept alive: the app root reads it on
/// every frame, so a change applies to every screen at once.
// ponytail: System until prefs.json is read (a few ms after launch, under
// the launch screen).
@Riverpod(keepAlive: true)
class AppLanguageSetting extends _$AppLanguageSetting {
  @override
  AppLanguage build() {
    final name = ref.watch(prefsProvider).value?[appLanguageKey];
    return AppLanguage.values.firstWhere(
      (l) => l.name == name,
      orElse: () => AppLanguage.system,
    );
  }

  void select(AppLanguage language) {
    state = language;
    unawaited(
      ref.read(prefsProvider.notifier).set(appLanguageKey, language.name),
    );
  }
}
