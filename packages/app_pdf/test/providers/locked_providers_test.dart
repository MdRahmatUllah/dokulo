import 'dart:convert';

import 'package:app_pdf/providers/locked_providers.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemorySecretStore store;
  late DateTime now;
  var biometricResult = true;
  Object? biometricError;
  late LockedVault vault;

  setUp(() {
    store = MemorySecretStore();
    now = DateTime(2026, 10, 9, 12);
    biometricResult = true;
    biometricError = null;
    vault = LockedVault(
      store,
      clock: () => now,
      biometrics: (_) async {
        if (biometricError != null) throw biometricError!;
        return biometricResult;
      },
    );
  });

  test('setPin makes the key once; the PIN is stored only hashed', () async {
    expect(await vault.hasPin, isFalse);
    await vault.setPin('482915');
    final key = store.values['locked.key'];
    expect(key, isNotNull);
    expect(base64.decode(key!), hasLength(32));
    expect(store.values.values.join(), isNot(contains('482915')));
    await vault.setPin('111111'); // a change keeps the key
    expect(store.values['locked.key'], key);
  });

  test(
    'the right PIN releases a working cipher; a wrong one never does',
    () async {
      await vault.setPin('482915');
      final wrong = await vault.unlockWithPin('000000');
      expect(wrong, isA<PinWrong>());
      final right = await vault.unlockWithPin('482915');
      expect(right, isA<PinUnlocked>());
      final cipher = (right as PinUnlocked).cipher;
      final sealed = await cipher.seal(utf8.encode('Kontoauszug'));
      expect(utf8.decode(await cipher.open(sealed)), 'Kontoauszug');
    },
  );

  test(
    'after 5 wrong PINs even the right one waits, across a restart',
    () async {
      await vault.setPin('482915');
      for (var i = 0; i < 4; i++) {
        expect(await vault.unlockWithPin('000000'), isA<PinWrong>());
      }
      final fifth = await vault.unlockWithPin('000000');
      expect((fifth as PinWrong).wait, const Duration(seconds: 30));

      // A new vault on the same storage: the app was restarted.
      final again = LockedVault(
        store,
        clock: () => now,
        biometrics: (_) async => true,
      );
      final throttled = await again.unlockWithPin('482915');
      expect(throttled, isA<PinThrottled>());
      expect((throttled as PinThrottled).wait, const Duration(seconds: 30));

      now = now.add(const Duration(seconds: 31));
      expect(await again.unlockWithPin('482915'), isA<PinUnlocked>());
      // The right PIN reset it: a wrong one is just wrong again.
      expect((await again.unlockWithPin('0') as PinWrong).wait, Duration.zero);
    },
  );

  test('biometrics release the key only on success', () async {
    expect(
      await vault.unlockWithBiometrics('Unlock'),
      isNull,
      reason: 'no key yet',
    );
    await vault.setPin('482915');
    expect(await vault.unlockWithBiometrics('Unlock'), isA<LockedCipher>());
    biometricResult = false;
    expect(await vault.unlockWithBiometrics('Unlock'), isNull);
    biometricError = PlatformException(code: 'NotEnrolled');
    expect(await vault.unlockWithBiometrics('Unlock'), isNull);
  });

  test(
    'a cipher from the PIN and one from biometrics are the same key',
    () async {
      await vault.setPin('482915');
      final byPin = (await vault.unlockWithPin('482915') as PinUnlocked).cipher;
      final byFace = (await vault.unlockWithBiometrics('Unlock'))!;
      final sealed = await byPin.seal([1, 2, 3]);
      expect(await byFace.open(sealed), [1, 2, 3]);
    },
  );
}
