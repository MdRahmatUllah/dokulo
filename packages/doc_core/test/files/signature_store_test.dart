import 'dart:io';
import 'dart:typed_data';

import 'package:doc_core/doc_core.dart';
import 'package:test/test.dart';

void main() {
  late DokuloDatabase db;
  late Directory dir;
  late SignatureStore store;
  // A PNG's signature, then some bytes: what the pad hands over.
  final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]);

  setUp(() async {
    db = DokuloDatabase.memory();
    dir = await Directory.systemTemp.createTemp('signatures_');
    store = SignatureStore(db, dir, LockedCipher(List.filled(32, 7)));
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('a saved signature is sealed on disk and opens again', () async {
    final id = await store.add(
      SignatureKind.signature,
      png,
      ink: SignatureInk.blue,
    );
    final files = dir.listSync().whereType<File>().toList();
    expect(files, hasLength(1));
    final onDisk = files.single.readAsBytesSync();
    expect(LockedCipher.isSealed(onDisk), isTrue);
    expect(
      String.fromCharCodes(onDisk).contains('PNG'),
      isFalse,
      reason: 'never written in the clear',
    );
    expect(await store.image(id), png);
  });

  test('the list: kind, ink and date, newest first', () async {
    await store.add(
      SignatureKind.signature,
      png,
      now: DateTime.utc(2026, 10, 1),
    );
    await store.add(
      SignatureKind.initials,
      png,
      ink: SignatureInk.blue,
      now: DateTime.utc(2026, 10, 2),
    );
    final list = await store.list();
    expect(
      [for (final s in list) (s.kind, s.ink)],
      [
        (SignatureKind.initials, SignatureInk.blue),
        (SignatureKind.signature, SignatureInk.black),
      ],
    );
  });

  test('delete removes the file and the row', () async {
    final id = await store.add(SignatureKind.signature, png);
    await store.delete(id);
    expect(await store.list(), isEmpty);
    expect(dir.listSync(), isEmpty);
  });

  test('another key cannot open it', () async {
    final id = await store.add(SignatureKind.signature, png);
    final other = SignatureStore(db, dir, LockedCipher(List.filled(32, 9)));
    expect(other.image(id), throwsA(isA<LockedDataException>()));
  });
}
