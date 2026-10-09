import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// The locked folder's encryption at rest (DK-0282): AES-256-GCM with one
/// key per install. The app keeps the key in the Keychain / Keystore and
/// releases it only after biometrics or the PIN ([PinHash], [PinThrottle]).
/// Files and their thumbnails are sealed the same way.
///
/// A sealed file is "DKLK1", the 12-byte nonce, the cipher text and the
/// 16-byte tag. A wrong key or a changed byte fails with
/// [LockedDataException]; nothing is ever decrypted half-way.
class LockedCipher {
  LockedCipher(List<int> key) : _key = SecretKey(List.unmodifiable(key)) {
    if (key.length != 32) throw ArgumentError('a 256-bit key, 32 bytes');
  }

  static final _aes = AesGcm.with256bits();
  static const _magic = [0x44, 0x4B, 0x4C, 0x4B, 0x31]; // DKLK1
  final SecretKey _key;

  /// A new random key for a new install's locked folder.
  static Future<List<int>> newKey() async =>
      (await _aes.newSecretKey()).extractBytes();

  /// Whether [bytes] are sealed by [LockedCipher] (any key).
  static bool isSealed(List<int> bytes) =>
      bytes.length > _magic.length &&
      Iterable<int>.generate(_magic.length).every((i) => bytes[i] == _magic[i]);

  Future<Uint8List> seal(List<int> clear) async {
    final box = await _aes.encrypt(clear, secretKey: _key);
    return Uint8List.fromList([..._magic, ...box.concatenation()]);
  }

  Future<Uint8List> open(List<int> sealed) async {
    if (!isSealed(sealed)) throw const LockedDataException('not sealed');
    try {
      final box = SecretBox.fromConcatenation(
        sealed.sublist(_magic.length),
        nonceLength: _aes.nonceLength,
        macLength: _aes.macAlgorithm.macLength,
      );
      return Uint8List.fromList(await _aes.decrypt(box, secretKey: _key));
    } on SecretBoxAuthenticationError {
      throw const LockedDataException('wrong key or changed data');
    } on ArgumentError {
      throw const LockedDataException('too short');
    }
  }

  // ponytail: whole files in memory; seal in chunks if locked files outgrow
  // a phone's memory (scans are tens of MB).
  Future<void> sealFile(File clear, File sealed) async =>
      sealed.writeAsBytes(await seal(await clear.readAsBytes()), flush: true);

  Future<void> openFile(File sealed, File clear) async =>
      clear.writeAsBytes(await open(await sealed.readAsBytes()), flush: true);
}

class LockedDataException implements Exception {
  const LockedDataException(this.message);
  final String message;
  @override
  String toString() => 'LockedDataException: $message';
}

/// The locked folder's PIN, never stored in plain text: PBKDF2-HMAC-SHA256
/// with a random salt, as "pbkdf2-sha256$iterations$salt$hash" (base64).
abstract final class PinHash {
  static const iterations = 210000; // OWASP 2023 for PBKDF2-HMAC-SHA256

  static Future<String> create(
    String pin, {
    int iterations = iterations,
  }) async {
    final salt = SecretKeyData.random(length: 16).bytes;
    final hash = await _derive(pin, salt, iterations);
    return 'pbkdf2-sha256\$$iterations\$${base64.encode(salt)}\$${base64.encode(hash)}';
  }

  static Future<bool> verify(String pin, String stored) async {
    final parts = stored.split(r'$');
    final rounds = parts.length == 4 ? int.tryParse(parts[1]) : null;
    if (parts[0] != 'pbkdf2-sha256' || rounds == null || rounds < 1) {
      return false;
    }
    final List<int> salt, expected;
    try {
      salt = base64.decode(parts[2]);
      expected = base64.decode(parts[3]);
    } on FormatException {
      return false;
    }
    final hash = await _derive(pin, salt, rounds);
    // Constant time: compare every byte.
    var diff = hash.length ^ expected.length;
    for (var i = 0; i < hash.length && i < expected.length; i++) {
      diff |= hash[i] ^ expected[i];
    }
    return diff == 0;
  }

  static Future<List<int>> _derive(String pin, List<int> salt, int n) async =>
      (await Pbkdf2.hmacSha256(iterations: n, bits: 256).deriveKey(
        secretKey: SecretKey(utf8.encode(pin)),
        nonce: salt,
      )).extractBytes();
}

/// Wrong PINs: after 5 in a row the next try waits 30 s, then twice as long
/// after each further miss (to 1 h). A right PIN resets it. The app stores
/// [failures] and [lastFailure] with the key, so a restart doesn't reset it.
class PinThrottle {
  PinThrottle({this.failures = 0, this.lastFailure});

  static const free = 5;
  static const firstWait = Duration(seconds: 30);
  static const maxWait = Duration(hours: 1);

  int failures;
  DateTime? lastFailure;

  /// How long until the next try is allowed; zero when it is.
  Duration waitAt(DateTime now) {
    if (failures < free || lastFailure == null) return Duration.zero;
    final wait = firstWait * (1 << (failures - free).clamp(0, 7));
    final capped = wait > maxWait ? maxWait : wait;
    final left = lastFailure!.add(capped).difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  void failed(DateTime now) {
    failures++;
    lastFailure = now;
  }

  void succeeded() {
    failures = 0;
    lastFailure = null;
  }
}
