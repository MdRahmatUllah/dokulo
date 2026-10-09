import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/database_providers.dart';
import '../providers/file_providers.dart';
import '../providers/files_providers.dart';
import '../routes/routes.dart';

/// The system's document picker for one PDF: its path, or null when the user
/// cancelled. A provider, so tests pick without a platform.
final pickPdfProvider = Provider<Future<String?> Function()>(
  (ref) => () async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    return picked.isEmpty ? null : picked.single.path;
  },
);

/// "Open a file" (DK-0241; H1, F1's empty root, O3): the system picker, a
/// copy in Dokulo's folder, indexed ([FileStore.importToUserFolder]), at the
/// top of Recent, then V1. Nothing happens when the picker is cancelled.
Future<void> openFileFromDevice(BuildContext context, WidgetRef ref) async {
  final path = await ref.read(pickPdfProvider)();
  if (path == null) return;
  final db = ref.read(appDatabaseProvider);
  final store = await ref.read(fileStoreProvider.future);
  final id = await store.importToUserFolder(db, File(path));
  await recordOpened(db, id);
  if (context.mounted) await context.push(Routes.viewer('$id'));
}
