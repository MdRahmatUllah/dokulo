import 'dart:convert';

import 'package:doc_core/doc_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'locked_providers.g.dart';

/// Where the locked folder keeps its secrets: the Keychain on iOS, the
/// Keystore-backed storage on Android. Tests use [MemorySecretStore].
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class KeychainSecretStore implements SecretStore {
  const KeychainSecretStore();
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MemorySecretStore implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// What a PIN try did.
sealed class PinResult {
  const PinResult();
}

/// The PIN was right: the folder's cipher.
class PinUnlocked extends PinResult {
  const PinUnlocked(this.cipher);
  final LockedCipher cipher;
}

/// The PIN was wrong; [wait] is how long until the next try (zero: now).
class PinWrong extends PinResult {
  const PinWrong(this.wait);
  final Duration wait;
}

/// Too many wrong PINs: no try until [wait] has passed (the PIN wasn't
/// even checked).
class PinThrottled extends PinResult {
  const PinThrottled(this.wait);
  final Duration wait;
}

/// The locked folder's key (DK-0282): made once per install, kept in the
/// [SecretStore], and handed out only after biometrics or the right PIN.
/// The PIN is stored only as a [PinHash]; wrong PINs are throttled
/// ([PinThrottle]), and the throttle survives a restart.
class LockedVault {
  LockedVault(
    this._store, {
    required this.biometrics,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final SecretStore _store;

  /// Shows the system's biometric prompt with [reason]; true on success.
  final Future<bool> Function(String reason) biometrics;
  final DateTime Function() _now;

  static const _key = 'locked.key',
      _pin = 'locked.pin',
      _throttle = 'locked.throttle';

  Future<bool> get hasPin async => await _store.read(_pin) != null;

  /// Sets or changes the PIN; the first time, it also makes the key.
  Future<void> setPin(String pin) async {
    if (await _store.read(_key) == null) {
      await _store.write(_key, base64.encode(await LockedCipher.newKey()));
    }
    await _store.write(_pin, await PinHash.create(pin));
    await _store.delete(_throttle);
  }

  Future<PinResult> unlockWithPin(String pin) async {
    final throttle = await _readThrottle();
    final now = _now();
    final wait = throttle.waitAt(now);
    if (wait > Duration.zero) return PinThrottled(wait);
    final stored = await _store.read(_pin);
    if (stored != null && await PinHash.verify(pin, stored)) {
      throttle.succeeded();
      await _store.delete(_throttle);
      return PinUnlocked(await _cipher());
    }
    throttle.failed(now);
    await _store.write(
      _throttle,
      '${throttle.failures} ${throttle.lastFailure!.toIso8601String()}',
    );
    return PinWrong(throttle.waitAt(now));
  }

  /// Null when the prompt was cancelled or failed, or there is no key yet.
  Future<LockedCipher?> unlockWithBiometrics(String reason) async {
    if (await _store.read(_key) == null) return null;
    try {
      if (!await biometrics(reason)) return null;
    } on PlatformException {
      return null; // no biometrics enrolled, or locked out: the PIN remains
    }
    return _cipher();
  }

  Future<LockedCipher> _cipher() async =>
      LockedCipher(base64.decode((await _store.read(_key))!));

  Future<PinThrottle> _readThrottle() async {
    final parts = (await _store.read(_throttle))?.split(' ');
    if (parts == null || parts.length != 2) return PinThrottle();
    return PinThrottle(
      failures: int.tryParse(parts[0]) ?? 0,
      lastFailure: DateTime.tryParse(parts[1]),
    );
  }
}

@Riverpod(keepAlive: true)
LockedVault lockedVault(Ref ref) {
  final auth = LocalAuthentication();
  return LockedVault(
    const KeychainSecretStore(),
    biometrics: (reason) =>
        auth.authenticate(localizedReason: reason, biometricOnly: true),
  );
}
