import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';

import '../db/database.dart';
import 'locked_crypto.dart';

enum SignatureKind { signature, initials }

enum SignatureInk { black, blue }

/// A saved signature or initials (its image is in [SignatureStore]).
typedef SavedSignature = ({
  int id,
  SignatureKind kind,
  SignatureInk ink,
  DateTime created,
});

/// Saved signatures and initials (DK-0325): transparent PNGs sealed with
/// [LockedCipher] in [directory] (a file never holds a clear image), and a
/// row each in `signatures` (kind, ink, date; `image_ref` is the file's
/// name). The cipher's key lives in the Keychain / Keystore.
class SignatureStore {
  SignatureStore(this._db, this.directory, this._cipher);

  final DokuloDatabase _db;
  final Directory directory;
  final LockedCipher _cipher;

  static final _random = Random.secure();

  /// Seals [png] and records it; returns its id.
  Future<int> add(
    SignatureKind kind,
    Uint8List png, {
    SignatureInk ink = SignatureInk.black,
    DateTime? now,
  }) async {
    await directory.create(recursive: true);
    final name =
        '${List.generate(16, (_) => _random.nextInt(16).toRadixString(16)).join()}.sig';
    // Written aside and renamed: a file there is always complete.
    final part = File('${directory.path}${Platform.pathSeparator}$name.part');
    await part.writeAsBytes(await _cipher.seal(png), flush: true);
    await part.rename(_file(name).path);
    try {
      return await _db
          .into(_db.signatures)
          .insert(
            SignaturesCompanion.insert(
              kind: kind.name,
              imageRef: name,
              createdAt: now ?? DateTime.now(),
              ink: Value(ink.name),
            ),
          );
    } catch (_) {
      // No row, no file: nothing points at it.
      await _file(name).delete();
      rethrow;
    }
  }

  /// Every saved one, newest first.
  Future<List<SavedSignature>> list() async => [
    for (final r in await (_db.select(
      _db.signatures,
    )..orderBy([(r) => OrderingTerm.desc(r.createdAt)])).get())
      (
        id: r.id,
        kind: SignatureKind.values.byName(r.kind),
        ink: SignatureInk.values.byName(r.ink),
        created: r.createdAt,
      ),
  ];

  /// The PNG of [id], opened in memory only.
  Future<Uint8List> image(int id) async {
    final row = await (_db.select(
      _db.signatures,
    )..where((r) => r.id.equals(id))).getSingle();
    return _cipher.open(await _file(row.imageRef).readAsBytes());
  }

  /// Deletes [id]: its row, then its file (a file left behind points at
  /// nothing; a row left behind would point at a missing file).
  Future<void> delete(int id) async {
    final row = await (_db.select(
      _db.signatures,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await (_db.delete(_db.signatures)..where((r) => r.id.equals(id))).go();
    final file = _file(row.imageRef);
    if (await file.exists()) await file.delete();
  }

  /// The saved ones that open, newest first, with their PNGs (DK-1083). One
  /// that can never open again (its file gone, or sealed with a key that is
  /// gone, as after a restore on a new phone) is deleted, so it can't hide
  /// the others; any other error is passed on.
  Future<List<(SavedSignature, Uint8List)>> readable() async {
    final out = <(SavedSignature, Uint8List)>[];
    for (final s in await list()) {
      try {
        out.add((s, await image(s.id)));
      } on LockedDataException {
        await delete(s.id);
      } on PathNotFoundException {
        await delete(s.id);
      }
    }
    return out;
  }

  File _file(String name) =>
      File('${directory.path}${Platform.pathSeparator}$name');
}
