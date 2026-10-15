import 'dart:io';
import 'dart:isolate';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_vision/doc_vision.dart';

/// One page of a scan as S2 left it: the photo on disk and the user's edits.
typedef ScanSavePage = ({
  String photo,

  /// Corners as fractions of the photo, clockwise from top-left; null: the
  /// whole photo.
  List<Pt>? corners,
  int turns,
  ScanFilter filter,
  double brightness,
  double contrast,
});

/// Saves a scan (DK-0359): each page warped, turned, filtered, scaled to
/// [longSide] and encoded as JPEG on a worker isolate (OpenCV), then either
/// one PDF `<base>.pdf` ([jpg] false; pages sized by [size]) or one JPEG per
/// page (`<base>.jpg`, or `<base> 1.jpg`, `<base> 2.jpg`, …). [onPage]
/// counts the pages done. Returns the files written; [workDir] holds the
/// page JPEGs meanwhile, and nothing is left there.
Future<List<String>> saveScan(
  List<ScanSavePage> pages, {
  required String base,
  required Directory workDir,
  bool jpg = false,
  ImagePageSize size = ImagePageSize.fit,
  int? longSide,
  int jpegQuality = 82,
  void Function(int done)? onPage,
}) async {
  if (pages.isEmpty) throw ArgumentError('no pages');
  final rendered = <String>[];
  try {
    for (final (i, p) in pages.indexed) {
      final out = '${workDir.path}/scan_page_$i.jpg';
      await Isolate.run(() {
        final page = renderScanPage((
          photo: File(p.photo).readAsBytesSync(),
          corners: p.corners,
          turns: p.turns,
          filter: p.filter,
          brightness: p.brightness,
          contrast: p.contrast,
          longSide: longSide,
          jpegQuality: jpegQuality,
        ));
        File(out).writeAsBytesSync(page.jpeg);
      });
      rendered.add(out);
      onPage?.call(i + 1);
    }
    if (jpg) {
      final names = rendered.length == 1
          ? ['$base.jpg']
          : [for (var i = 1; i <= rendered.length; i++) '$base $i.jpg'];
      for (final (i, path) in rendered.indexed) {
        File(path).renameSync(names[i]);
      }
      rendered.clear();
      return names;
    }
    final pdf = '$base.pdf';
    final work = workDir.path;
    await Isolate.run(() async {
      final writer = ImagesPdfWriter(pdf, workDir: Directory(work), size: size);
      for (final path in rendered) {
        await writer.add(File(path).readAsBytesSync());
      }
      // qpdf joins the batches only past ~96 MB of pages.
      await writer.close(IsolatePool(tempRoot: Directory(work)));
    });
    return [pdf];
  } finally {
    for (final path in rendered) {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    }
  }
}
