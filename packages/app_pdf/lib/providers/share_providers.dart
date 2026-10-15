import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

part 'share_providers.g.dart';

/// Sends files to the system share sheet (DK-1077): the real files, never
/// a link. Tests replace it.
typedef FileSharer = Future<void> Function(List<String> paths);

@Riverpod(keepAlive: true)
FileSharer fileSharer(Ref ref) =>
    (paths) => SharePlus.instance.share(
      ShareParams(files: [for (final p in paths) XFile(p)]),
    );
