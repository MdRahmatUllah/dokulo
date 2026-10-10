import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'prefs_providers.dart';

part 'security_providers.g.dart';

/// Settings → Security (DK-0573; UI spec §23.3), kept in [Prefs]: App lock
/// (off), Lock after (1 min). Hide previews lives in privacy_providers.
class SecuritySettings {
  const SecuritySettings({this.appLock = false, this.lockAfter = 60});

  factory SecuritySettings.from(Map<String, Object?> prefs) => SecuritySettings(
    appLock: prefs['security.appLock'] == true,
    lockAfter: switch (prefs['security.lockAfter']) {
      final int s when lockAfterChoices.contains(s) => s,
      _ => 60,
    },
  );

  final bool appLock;

  /// Seconds in the background before the app locks: 0, 60 or 300.
  final int lockAfter;

  static const lockAfterChoices = [0, 60, 300];
}

@riverpod
SecuritySettings securitySettings(Ref ref) =>
    SecuritySettings.from(ref.watch(prefsProvider).value ?? const {});
