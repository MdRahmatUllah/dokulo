import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../l10n/app_language.dart';

part 'language_providers.g.dart';

/// System, English or Deutsch (Me → Settings → Language). Kept alive: the app
/// root reads it on every frame, so a change applies to every screen at once.
/// M3 persists it.
@Riverpod(keepAlive: true)
class AppLanguageSetting extends _$AppLanguageSetting {
  @override
  AppLanguage build() => AppLanguage.system;

  void select(AppLanguage language) => state = language;
}
