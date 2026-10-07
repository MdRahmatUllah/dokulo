import 'dart:io';

import 'package:doc_core/doc_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_providers.g.dart';

/// The user's visible folder and the sandbox (DK-0006). Kept alive: every
/// tool and the Files tab use it.
@Riverpod(keepAlive: true)
Future<FileStore> fileStore(Ref ref) async {
  final support = await getApplicationSupportDirectory();
  return FileStore(
    userFolder: Platform.isAndroid
        ? androidUserFolder((await getExternalStorageDirectory())!.path)
        // iOS: Documents, shown in the Files app under "On My iPhone › Dokulo"
        // (UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace).
        : await getApplicationDocumentsDirectory(),
    workDirectory: Directory('${support.path}${Platform.pathSeparator}work'),
  );
}

/// Android's public `Documents/Dokulo` on the primary volume, from the app's
/// external files directory (`<volume>/Android/data/<id>/files`). Apps may
/// create files there without a permission from Android 10 on
/// (requestLegacyExternalStorage on 10, WRITE_EXTERNAL_STORAGE up to 9).
Directory androidUserFolder(String externalFilesDir) {
  final i = externalFilesDir.indexOf('/Android/');
  if (i < 0) {
    throw StateError('Unexpected external files dir: $externalFilesDir');
  }
  return Directory('${externalFilesDir.substring(0, i)}/Documents/Dokulo');
}
