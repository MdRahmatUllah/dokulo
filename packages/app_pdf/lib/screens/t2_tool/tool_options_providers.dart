import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:doc_core/doc_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../tools/tool_definition.dart';

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

/// Page thumbnails on disk (DK-0390's ThumbnailCache), in app support.
@Riverpod(keepAlive: true, retry: _noRetry)
Future<ThumbnailCache> thumbnailCache(Ref ref) async {
  final support = await getApplicationSupportDirectory();
  return ThumbnailCache(
    Directory('${support.path}${Platform.pathSeparator}thumbnails'),
  );
}

/// The first page of the PDF at [path], 96 wide, for a DkFileCard. A file
/// that can't be rendered (damaged, locked) keeps its skeleton: no retry.
@Riverpod(retry: _noRetry)
Future<ui.Image> pdfThumbnail(Ref ref, String path) async {
  final cache = await ref.watch(thumbnailCacheProvider.future);
  final page = await cache.thumbnail(path, 1);
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    page.bgra,
    page.width,
    page.height,
    ui.PixelFormat.bgra8888,
    done.complete,
  );
  final image = await done.future;
  ref.onDispose(image.dispose);
  return image;
}

Duration? _noRetry(int retryCount, Object error) => null;
