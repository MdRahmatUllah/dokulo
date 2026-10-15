import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'prefs_providers.dart';

part 'privacy_providers.g.dart';

/// Settings → Security → Hide previews (UI spec §23.3; DK-0573): on by
/// default, kept in [Prefs].
@Riverpod(keepAlive: true)
class HidePreviews extends _$HidePreviews {
  @override
  bool build() =>
      ref.watch(prefsProvider).value?['security.hidePreviews'] != false;

  void set(bool on) {
    state = on;
    ref.read(prefsProvider.notifier).set('security.hidePreviews', on);
  }
}

/// How many screens with locked-folder content are open (F2 and what it
/// opens); DkLockedContent counts them.
@Riverpod(keepAlive: true)
class LockedContentOpen extends _$LockedContentOpen {
  @override
  int build() => 0;

  void enter() => state++;
  void leave() => state--;
}

/// Whether the app switcher must show the privacy cover instead of the
/// app (DK-0234): locked content is open, or Hide previews is on.
@Riverpod(keepAlive: true)
bool privacyCover(Ref ref) =>
    ref.watch(hidePreviewsProvider) || ref.watch(lockedContentOpenProvider) > 0;

/// Android's FLAG_SECURE (`MainActivity.kt`, channel `dokulo/privacy`): the
/// recents card is blank and screenshots are blocked, only while
/// [privacyCover] holds. iOS has no such flag: the cover is drawn.
abstract final class PrivacyChannel {
  static const channel = MethodChannel('dokulo/privacy');

  static Future<void> setSecure(bool on) async {
    try {
      await channel.invokeMethod<void>('setSecure', on);
    } on MissingPluginException {
      // iOS, tests and desktop: nothing to set.
    }
  }
}
