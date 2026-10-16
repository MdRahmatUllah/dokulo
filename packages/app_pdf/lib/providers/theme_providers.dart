import 'dart:async';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'prefs_providers.dart';

part 'theme_providers.g.dart';

/// The prefs key of the theme (a [ThemeMode] name).
const appThemeKey = 'app.theme';

/// Light, Dark or System (Me → Settings → Appearance, DK-0574), kept in
/// [Prefs]. Kept alive: the app root reads it on every frame.
@Riverpod(keepAlive: true)
class AppThemeMode extends _$AppThemeMode {
  @override
  ThemeMode build() {
    final name = ref.watch(prefsProvider).value?[appThemeKey];
    return ThemeMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ThemeMode.system,
    );
  }

  void select(ThemeMode mode) {
    state = mode;
    unawaited(ref.read(prefsProvider.notifier).set(appThemeKey, mode.name));
  }
}
