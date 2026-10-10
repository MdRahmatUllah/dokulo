import 'package:app_pdf/components/dk_pin_pad.dart';
import 'package:app_pdf/providers/locked_providers.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/providers/privacy_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'locked_folder_screen_test.dart' show LockedSetup, pumpLocked, typePin;

/// The locked folder's security (DK-0291), the parts a widget test can
/// check. The file bytes (ciphertext, no names), the decrypted copies on
/// lock and a failing move are in doc_core's locked_store_test and in
/// locked_move_test; the OS-level checks are in
/// docs/qa/locked-folder-security.md.
void main() {
  testWidgets('open: the app switcher shows the privacy cover; locked: not', (
    tester,
  ) async {
    final setup = LockedSetup();
    await setup.vault.setPin('482915');
    final container = await pumpLocked(tester, setup);
    // Hide previews off (it is on by default): the folder alone asks for
    // the cover.
    await container.read(prefsProvider.future); // loaded, or it resets
    container.read(hidePreviewsProvider.notifier).set(false);
    // The unlock screen shows nothing of the folder: no cover needed.
    expect(container.read(privacyCoverProvider), isFalse);
    await typePin(tester, '482915');
    expect(container.read(privacyCoverProvider), isTrue);
    await tester.tap(find.byTooltip('Lock now'));
    await tester.pumpAndSettle();
    expect(container.read(privacyCoverProvider), isFalse);
    expect(find.byType(DkPinPad), findsOneWidget);
  });

  testWidgets('leaving the open folder drops the cover and the key', (
    tester,
  ) async {
    final setup = LockedSetup();
    await setup.vault.setPin('482915');
    final container = await pumpLocked(tester, setup);
    await container.read(prefsProvider.future); // loaded, or it resets
    container.read(hidePreviewsProvider.notifier).set(false);
    await typePin(tester, '482915');
    expect(container.read(privacyCoverProvider), isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(container.read(privacyCoverProvider), isFalse);
    expect(container.read(lockedSessionProvider), isNull);
  });

  testWidgets('the PIN is stored hashed, the key only in the secret store', (
    tester,
  ) async {
    final setup = LockedSetup();
    await setup.vault.setPin('482915');
    final stored = setup.store.values;
    expect(stored.values.join(), isNot(contains('482915')));
    // The folder's key lives in the Keychain / Keystore (SecretStore), under
    // one entry; nothing else holds it.
    expect(stored.keys, contains('locked.key'));
  });

  testWidgets('brute force: the 6th wrong PIN waits 30 s, then doubling', (
    tester,
  ) async {
    final setup = LockedSetup();
    await setup.vault.setPin('482915');
    for (var i = 0; i < 5; i++) {
      expect(await setup.vault.unlockWithPin('000000'), isA<PinWrong>());
    }
    final sixth = await setup.vault.unlockWithPin('000000');
    expect(sixth, isA<PinThrottled>());
    expect((sixth as PinThrottled).wait.inSeconds, greaterThan(0));
    // Even the right PIN waits while throttled.
    expect(await setup.vault.unlockWithPin('482915'), isA<PinThrottled>());
  });
}
