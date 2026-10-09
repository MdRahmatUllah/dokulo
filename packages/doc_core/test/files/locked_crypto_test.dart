import 'dart:convert';
import 'dart:io';

import 'package:doc_core/doc_core.dart';
import 'package:test/test.dart';

void main() {
  group('LockedCipher', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('dk_lock_'));
    tearDown(() => dir.delete(recursive: true));

    const pdf =
        '%PDF-1.7\n1 0 obj << /Type /Catalog >> endobj\nKontoauszug IBAN DE89';

    test('a sealed file on disk shows none of its content', () async {
      final cipher = LockedCipher(await LockedCipher.newKey());
      final clear = File('${dir.path}/a.pdf')..writeAsStringSync(pdf);
      final sealed = File('${dir.path}/a.pdf.dklk');
      await cipher.sealFile(clear, sealed);
      final raw = sealed.readAsBytesSync();
      final text = latin1.decode(raw);
      expect(text, isNot(contains('%PDF')));
      expect(text, isNot(contains('IBAN')));
      expect(LockedCipher.isSealed(raw), isTrue);
      final back = File('${dir.path}/b.pdf');
      await cipher.openFile(sealed, back);
      expect(back.readAsStringSync(), pdf);
    });

    test('the same file seals differently each time (a fresh nonce)', () async {
      final cipher = LockedCipher(await LockedCipher.newKey());
      final a = await cipher.seal(utf8.encode(pdf));
      final b = await cipher.seal(utf8.encode(pdf));
      expect(a, isNot(equals(b)));
    });

    test('the wrong key opens nothing', () async {
      final sealed = await LockedCipher(await LockedCipher.newKey())
          .seal(utf8.encode(pdf));
      final other = LockedCipher(await LockedCipher.newKey());
      expect(other.open(sealed), throwsA(isA<LockedDataException>()));
    });

    test('a changed byte is caught', () async {
      final cipher = LockedCipher(await LockedCipher.newKey());
      final sealed = await cipher.seal(utf8.encode(pdf));
      sealed[sealed.length ~/ 2] ^= 1;
      expect(cipher.open(sealed), throwsA(isA<LockedDataException>()));
    });

    test('plain or short bytes are refused', () async {
      final cipher = LockedCipher(await LockedCipher.newKey());
      expect(
        cipher.open(utf8.encode(pdf)),
        throwsA(isA<LockedDataException>()),
      );
      expect(
        cipher.open([0x44, 0x4B, 0x4C, 0x4B, 0x31, 1]),
        throwsA(isA<LockedDataException>()),
      );
      expect(() => LockedCipher([1, 2, 3]), throwsArgumentError);
    });
  });

  group('PinHash', () {
    test('verifies the right PIN only; the PIN is not in the hash', () async {
      final stored = await PinHash.create('482915', iterations: 1000);
      expect(stored, isNot(contains('482915')));
      expect(await PinHash.verify('482915', stored), isTrue);
      expect(await PinHash.verify('482916', stored), isFalse);
      expect(await PinHash.verify('', stored), isFalse);
    });

    test('the same PIN hashes differently (a random salt)', () async {
      final a = await PinHash.create('1234', iterations: 1000);
      final b = await PinHash.create('1234', iterations: 1000);
      expect(a, isNot(b));
    });

    test('a damaged stored value never verifies', () async {
      expect(await PinHash.verify('1234', 'nonsense'), isFalse);
    });
  });

  group('PinThrottle', () {
    final t0 = DateTime(2026, 10, 9, 12);

    test('5 free tries, then 30 s, doubling, capped at 1 h', () {
      final throttle = PinThrottle();
      for (var i = 0; i < 4; i++) {
        throttle.failed(t0);
        expect(throttle.waitAt(t0), Duration.zero);
      }
      throttle.failed(t0); // the 5th miss
      expect(throttle.waitAt(t0), const Duration(seconds: 30));
      expect(
        throttle.waitAt(t0.add(const Duration(seconds: 31))),
        Duration.zero,
      );
      throttle.failed(t0);
      expect(throttle.waitAt(t0), const Duration(seconds: 60));
      for (var i = 0; i < 20; i++) {
        throttle.failed(t0);
      }
      expect(throttle.waitAt(t0), PinThrottle.maxWait);
    });

    test('a right PIN resets it', () {
      final throttle = PinThrottle();
      for (var i = 0; i < 6; i++) {
        throttle.failed(t0);
      }
      throttle.succeeded();
      expect(throttle.waitAt(t0), Duration.zero);
      expect(throttle.failures, 0);
    });
  });
}
