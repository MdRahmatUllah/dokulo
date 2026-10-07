import 'dart:io';
import 'dart:typed_data';

import 'pdf_engine.dart';

/// Page thumbnails on disk (DK-0390): rendered once per file version, page
/// and width, then read back. A file is 8 bytes (width, height as uint32)
/// followed by the BGRA pixels, which the UI hands to
/// `decodeImageFromPixels` as they are. Editing a file changes its mtime and
/// so its key; [clear] drops everything (Settings → Clear cache).
class ThumbnailCache {
  ThumbnailCache(this.directory);

  final Directory directory;

  Future<RenderedPage> thumbnail(
    String path,
    int page, {
    int width = 96,
  }) async {
    final modified = (await File(path).stat()).modified.microsecondsSinceEpoch;
    final file = File(
      '${directory.path}${Platform.pathSeparator}${_key('$path|$modified|$page|$width')}.bgra',
    );
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      final size = ByteData.sublistView(bytes, 0, 8);
      return RenderedPage(
        width: size.getUint32(0),
        height: size.getUint32(4),
        bgra: Uint8List.sublistView(bytes, 8),
      );
    }
    final rendered = await PdfEngine.render(path, page, width: width);
    await directory.create(recursive: true);
    final header = ByteData(8)
      ..setUint32(0, rendered.width)
      ..setUint32(4, rendered.height);
    await file.writeAsBytes([...header.buffer.asUint8List(), ...rendered.bgra]);
    return rendered;
  }

  Future<void> clear() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  /// FNV-1a, 64-bit: a stable file name for the key (String.hashCode isn't
  /// stable across runs).
  static String _key(String key) {
    var hash = 0xcbf29ce484222325;
    for (final unit in key.codeUnits) {
      hash = (hash ^ unit) * 0x100000001b3;
    }
    return hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
  }
}
