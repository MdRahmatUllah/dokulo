import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:doc_core/doc_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'database_providers.dart';
import 'locked_providers.dart';

part 'signature_providers.g.dart';

/// Where the signatures' key is kept: the Keychain / Keystore.
@Riverpod(keepAlive: true)
SecretStore signatureSecrets(Ref ref) => const KeychainSecretStore();

/// The saved signatures' store (DK-0325). Its key is its own, not the
/// locked folder's: signing never asks for the PIN, but a signature is
/// never on disk in the clear. Made on first use.
@Riverpod(keepAlive: true)
Future<SignatureStore> signatureStore(Ref ref) async {
  const name = 'signatures_key';
  final secrets = ref.watch(signatureSecretsProvider);
  var key = await secrets.read(name);
  if (key == null) {
    key = base64Encode(await LockedCipher.newKey());
    await secrets.write(name, key);
  }
  final support = await getApplicationSupportDirectory();
  return SignatureStore(
    ref.watch(appDatabaseProvider),
    Directory('${support.path}${Platform.pathSeparator}signatures'),
    LockedCipher(base64Decode(key)),
  );
}

/// The saved signatures with their images (decrypted in memory), newest
/// first: Me → Signatures and the Signatures sheet.
@Riverpod(keepAlive: true)
class Signatures extends _$Signatures {
  @override
  Future<List<(SavedSignature, Uint8List)>> build() async {
    final store = await ref.watch(signatureStoreProvider.future);
    // One that can't open is dropped, not the whole list (DK-1083).
    return store.readable();
  }

  Future<void> add(SignatureKind kind, Uint8List png, SignatureInk ink) async {
    final store = await ref.read(signatureStoreProvider.future);
    await store.add(kind, png, ink: ink);
    ref.invalidateSelf();
    await future;
  }

  Future<void> delete(int id) async {
    final store = await ref.read(signatureStoreProvider.future);
    await store.delete(id);
    ref.invalidateSelf();
    await future;
  }
}
