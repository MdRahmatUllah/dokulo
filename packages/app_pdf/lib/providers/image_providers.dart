import 'dart:io';

import 'package:doc_core/doc_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Turns a HEIC/HEIF photo at `from` into an upright JPEG at `to` with the
/// platform's decoder (DK-1081): `ImageDecoder` on Android 9+, `UIImage` on
/// iOS (channel `dokulo/images`, `MainActivity.kt` / `AppDelegate.swift`).
/// False when this phone can't (Android 8) or the photo doesn't decode.
/// Tests override it.
typedef HeicDecoder = Future<bool> Function(String from, String to);

final heicDecoderProvider = Provider<HeicDecoder>(
  (ref) => (from, to) async {
    try {
      return await const MethodChannel('dokulo/images')
              .invokeMethod<bool>('heicToJpeg', {'from': from, 'to': to}) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  },
);

bool isHeic(String path) =>
    RegExp(r'\.hei[cf]$', caseSensitive: false).hasMatch(path);

/// Picked images made ready for an image tool (DK-1081): the engine reads
/// JPEG, PNG and WebP but not HEIC, so each HEIC/HEIF becomes a JPEG in the
/// store's temp folder first (EXIF orientation applied); one the phone
/// can't decode is left out and counted, for the "skipped" message. Other
/// files pass as they are.
Future<({List<String> paths, int skipped})> prepareImages(
  List<String> paths,
  FileStore store,
  HeicDecoder decode,
) async {
  final ready = <String>[];
  var skipped = 0;
  for (final path in paths) {
    if (!isHeic(path)) {
      ready.add(path);
      continue;
    }
    final name = File(path).uri.pathSegments.last;
    final jpeg = await store.newTempFile(
      '${name.substring(0, name.lastIndexOf('.'))}.jpg',
    );
    if (await decode(path, jpeg.path)) {
      ready.add(jpeg.path);
    } else {
      skipped++;
    }
  }
  return (paths: ready, skipped: skipped);
}
