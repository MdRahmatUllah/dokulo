import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:doc_vision/doc_vision.dart';

/// The signature pad's Image tab (DK-1084): the photo at [path] as a
/// signature PNG (black ink on transparency), on a worker isolate.
/// [FormatException] when it isn't an image or holds no ink.
Future<Uint8List> signatureFromPhoto(String path) =>
    Isolate.run(() => signatureFromPhotoSync(File(path).readAsBytesSync()));
