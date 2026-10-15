import 'dart:convert';
import 'dart:io';

import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

void main() {
  late Directory dir, work;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dk_scan_save_');
    work = Directory('${dir.path}/work')..createSync();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  /// An 800 × 1000 photo: a white page on a dark desk.
  String photo(String name) {
    final im = img.Image(width: 800, height: 1000);
    img.fill(im, color: img.ColorRgb8(40, 40, 40));
    img.fillRect(
      im,
      x1: 100,
      y1: 100,
      x2: 700,
      y2: 900,
      color: img.ColorRgb8(240, 240, 240),
    );
    return (File(
      '${dir.path}/$name',
    )..writeAsBytesSync(img.encodeJpg(im))).path;
  }

  ScanSavePage page(String path, {int turns = 0}) => (
    photo: path,
    corners: const [
      (x: 0.125, y: 0.1),
      (x: 0.875, y: 0.1),
      (x: 0.875, y: 0.9),
      (x: 0.125, y: 0.9),
    ],
    turns: turns,
    filter: ScanFilter.original,
    brightness: 0,
    contrast: 0,
  );

  test('a PDF: every page cropped and turned, progress per page, '
      'no page JPEGs left behind', () async {
    final done = <int>[];
    final out = await saveScan(
      [page(photo('a.jpg')), page(photo('b.jpg'), turns: 1)],
      base: '${dir.path}/Scan',
      workDir: work,
      onPage: done.add,
    );
    expect(out, ['${dir.path}/Scan.pdf']);
    expect(
      File(out.single).readAsStringSync(encoding: latin1),
      contains('%PDF'),
    );
    expect(
      RegExp(r'/Type\s*/Page\b')
          .allMatches(File(out.single).readAsStringSync(encoding: latin1)),
      hasLength(2),
    );
    expect(done, [1, 2]);
    expect(work.listSync(), isEmpty);
  });

  test('JPG: one file per page, numbered; scaled to the long side', () async {
    final out = await saveScan(
      [page(photo('a.jpg')), page(photo('b.jpg'), turns: 1)],
      base: '${dir.path}/Scan',
      workDir: work,
      jpg: true,
      longSide: 400,
    );
    expect(out, ['${dir.path}/Scan 1.jpg', '${dir.path}/Scan 2.jpg']);
    final first = img.decodeJpg(File(out[0]).readAsBytesSync())!;
    final second = img.decodeJpg(File(out[1]).readAsBytesSync())!;
    // The 600 × 800 page, at most 400 long; the second turned a quarter.
    expect((first.width, first.height), (300, 400));
    expect((second.width, second.height), (400, 300));
    expect(work.listSync(), isEmpty);
  });

  test('one page as JPG keeps the plain name', () async {
    final out = await saveScan(
      [page(photo('a.jpg'))],
      base: '${dir.path}/Scan',
      workDir: work,
      jpg: true,
      size: ImagePageSize.a4,
    );
    expect(out, ['${dir.path}/Scan.jpg']);
  });
}
