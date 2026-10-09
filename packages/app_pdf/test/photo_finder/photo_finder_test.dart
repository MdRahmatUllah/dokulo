import 'dart:typed_data';

import 'package:app_pdf/photo_finder/photo_finder.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLibrary implements PhotoLibrary {
  FakeLibrary(this.photos, {this.access = true});
  final List<LibraryPhoto> photos;
  bool access;
  final thumbs = <String>[];

  @override
  Future<bool> requestAccess() async => access;
  @override
  Future<int> count() async => photos.length;
  @override
  Future<List<LibraryPhoto>> range(int start, int end) async =>
      photos.sublist(start, end);
  @override
  Future<Uint8List?> thumbnail(String id, {int size = 320}) async {
    thumbs.add(id);
    return Uint8List.fromList(id.codeUnits);
  }
}

/// The fake scorer reads the "thumbnail" (the id): doc-NN scores 0.NN.
Future<double> score(Uint8List bytes) async {
  final id = String.fromCharCodes(bytes);
  return id.startsWith('doc-') ? int.parse(id.substring(4)) / 100 : 0.1;
}

void main() {
  late DokuloDatabase db;
  late FakeLibrary library;
  final t0 = DateTime.utc(2026, 10, 1);

  ProviderContainer finder() {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        photoLibraryProvider.overrideWithValue(library),
        documentScorerProvider.overrideWithValue(score),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    db = DokuloDatabase.memory();
    library = FakeLibrary([
      (id: 'doc-90', modified: t0),
      (id: 'cat', modified: t0),
      (id: 'doc-60', modified: t0),
      (id: 'doc-40', modified: t0),
      (id: 'beach', modified: t0),
    ]);
  });
  tearDown(() => db.close());

  test('scores every photo; the documents come out best first', () async {
    final c = finder();
    expect(
      await c.read(photoFinderProvider.notifier).scan(pageSize: 2),
      isTrue,
    );
    final s = c.read(photoFinderProvider);
    expect((s.scanned, s.total, s.running), (5, 5, false));
    expect(
      [for (final p in s.found) p.id],
      unorderedEquals(['doc-90', 'doc-60']),
      reason: 'doc-40 is under the threshold',
    );
  });

  test(
    'a rescan (after a restart) scores only new or changed photos',
    () async {
      await finder().read(photoFinderProvider.notifier).scan();
      library.thumbs.clear();
      library.photos
        ..[1] = (id: 'cat', modified: t0.add(const Duration(hours: 1)))
        ..add((id: 'doc-75', modified: t0));
      final c = finder();
      await c.read(photoFinderProvider.notifier).scan();
      expect(library.thumbs, unorderedEquals(['cat', 'doc-75']));
      expect([
        for (final p in c.read(photoFinderProvider).found) p.id,
      ], unorderedEquals(['doc-90', 'doc-75', 'doc-60']));
    },
  );

  test('"Not a document" is remembered, even when the photo changes', () async {
    final c = finder();
    final f = c.read(photoFinderProvider.notifier);
    await f.scan();
    await f.notADocument('doc-90');
    expect(
      [for (final p in c.read(photoFinderProvider).found) p.id],
      ['doc-60'],
    );
    library.photos[0] = (
      id: 'doc-90',
      modified: t0.add(const Duration(days: 1)),
    );
    await f.scan();
    expect(
      [for (final p in c.read(photoFinderProvider).found) p.id],
      ['doc-60'],
    );
  });

  test('earlier results load without scanning', () async {
    await finder().read(photoFinderProvider.notifier).scan();
    final c = finder();
    await c.read(photoFinderProvider.notifier).load();
    expect([
      for (final p in c.read(photoFinderProvider).found) p.id,
    ], unorderedEquals(['doc-90', 'doc-60']));
  });

  test('no access: nothing is scanned', () async {
    library.access = false;
    final c = finder();
    expect(await c.read(photoFinderProvider.notifier).scan(), isFalse);
    expect(library.thumbs, isEmpty);
  });
}
