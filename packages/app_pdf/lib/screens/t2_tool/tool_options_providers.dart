import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:doc_core/doc_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../components/dk_file_card.dart';
import '../../providers/database_providers.dart';
import '../../tools/tool_definition.dart';
import '../../tools/tool_inputs.dart';

part 'tool_options_providers.g.dart';

/// The options the user chose in a tool's T2, by option key (DK-0370). Kept
/// alive: going back from T2 and opening the tool again keeps them; Reset
/// options clears them. A key without a value takes its option's initial.
@Riverpod(keepAlive: true)
class ToolOptionValues extends _$ToolOptionValues {
  @override
  ToolValues build(String toolId) => const {};

  void set(String key, Object? value) => state = {...state, key: value};

  void reset() => state = const {};
}

/// The latest finished run: T2 sets it, then opens T3.
@Riverpod(keepAlive: true)
class LastToolResult extends _$LastToolResult {
  @override
  ToolResult? build() => null;

  void set(ToolResult result) => state = result;
}

/// Page thumbnails on disk (DK-0390's ThumbnailCache), in app support.
@Riverpod(keepAlive: true, retry: _noRetry)
Future<ThumbnailCache> thumbnailCache(Ref ref) async {
  final support = await getApplicationSupportDirectory();
  return ThumbnailCache(
    Directory('${support.path}${Platform.pathSeparator}thumbnails'),
  );
}

/// A page (1-based) of the PDF at [path], 96 wide, for a DkFileCard or a
/// preview strip. A file that can't be rendered (damaged, locked) keeps its
/// skeleton: no retry.
@Riverpod(retry: _noRetry)
Future<ui.Image> pdfThumbnail(Ref ref, String path, {int page = 1}) async {
  final cache = await ref.watch(thumbnailCacheProvider.future);
  final rendered = await cache.thumbnail(path, page);
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rendered.bgra,
    rendered.width,
    rendered.height,
    ui.PixelFormat.bgra8888,
    done.complete,
  );
  final image = await done.future;
  ref.onDispose(image.dispose);
  return image;
}

Duration? _noRetry(int retryCount, Object error) => null;

/// Picks files on the device: Browse device (the tool's kinds) or Choose
/// photos. Returns their paths; empty when the user cancels. Tests override
/// it.
typedef DevicePicker = Future<List<String>> Function(
  ToolInput input, {
  required bool photos,
});

@Riverpod(keepAlive: true)
DevicePicker devicePicker(Ref ref) => (input, {required photos}) async {
  final picked = await FilePicker.pickFiles(
    type: photos ? FileType.image : FileType.custom,
    allowedExtensions: photos
        ? null
        : [
            if (input.kinds.contains(DkFileKind.pdf)) 'pdf',
            if (input.images) ...['jpg', 'jpeg', 'png', 'heic', 'webp'],
          ],
  );
  final paths = [
    for (final f in picked)
      if (f.path case final String path) path,
  ];
  return input.many ? paths : paths.take(1).toList();
};

/// The 5 most recent files [toolId] can take, for T2's picker card
/// (DK-0371).
@riverpod
Future<List<FileEntry>> recentCompatibleFiles(Ref ref, String toolId) async {
  final input = ToolInput.of(toolId);
  if (input == null) return const [];
  final db = ref.watch(appDatabaseProvider);
  // ponytail: sorts the whole index in Dart; a recentFiles query in
  // schema.drift when people keep thousands of files.
  final all = await db.select(db.files).get()
    ..sort((a, b) => b.modified.compareTo(a.modified));
  return all.where((f) => input.takes(f.name)).take(5).toList();
}

/// Whether the PDF at [path] needs a password to open (DK-0372).
@Riverpod(retry: _noRetry)
Future<bool> pdfLocked(Ref ref, String path) async {
  if (ToolInput.kindOf(path) != DkFileKind.pdf) return false;
  try {
    await PdfEngine.inspect(path);
    return false;
  } on DocError catch (e) {
    return e.kind == DocErrorKind.locked;
  }
}
