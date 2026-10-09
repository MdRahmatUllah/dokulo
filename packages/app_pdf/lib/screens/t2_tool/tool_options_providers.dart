import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
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

/// A finished run, as T3 shows it (DK-0379): the inputs, what the job wrote
/// (in temp, until saved), and how long it took.
class ToolResult {
  const ToolResult({
    required this.toolId,
    required this.inputs,
    required this.output,
    required this.took,
  });

  final String toolId;
  final List<FileEntry> inputs;
  final JobOutput output;
  final Duration took;

  /// The files the job wrote.
  List<String> get files => switch (output) {
    OneFile(:final path) => [path],
    ManyFiles(:final paths) => paths,
    TextOutput() => const [],
  };
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
