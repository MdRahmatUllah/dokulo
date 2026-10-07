import 'dart:io';

import 'package:doc_core/doc_core.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

void main() {
  late Directory root;
  setUpAll(pdfrxInitialize);
  setUp(() async => root = await Directory.systemTemp.createTemp('dk_thumbs_'));
  tearDown(() => root.delete(recursive: true));

  test(
    'a thumbnail is rendered once, then read from disk; an edit re-renders',
    () async {
      final pdf = File('${root.path}/Invoice.pdf');
      await File('../../test/fixtures/Invoice INV-2026-014.pdf').copy(pdf.path);
      final cache = ThumbnailCache(Directory('${root.path}/thumbs'));

      final first = await cache.thumbnail(pdf.path, 0);
      expect((first.width, first.height), (96, 136));
      expect(cache.directory.listSync(), hasLength(1));

      final again = await cache.thumbnail(pdf.path, 0);
      expect((again.width, again.height), (96, 136));
      expect(again.bgra, first.bgra);
      expect(cache.directory.listSync(), hasLength(1));

      // A changed file (new mtime) gets a new thumbnail.
      await pdf.setLastModified(DateTime(2030));
      await cache.thumbnail(pdf.path, 0);
      expect(cache.directory.listSync(), hasLength(2));

      await cache.clear();
      expect(cache.directory.existsSync(), isFalse);
    },
  );
}
