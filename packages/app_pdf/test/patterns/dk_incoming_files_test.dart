import 'dart:async';
import 'dart:io';

import 'package:app_pdf/components/dk_tool_tile.dart';
import 'package:app_pdf/patterns/dk_incoming_files.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../screens/files_screen_test.dart' show FilesFixture, pumpFiles, settle;

void main() {
  late FilesFixture f;
  late Directory cache;
  setUp(() async {
    f = FilesFixture();
    await f.setUp();
    cache = await Directory('${f.root.path}/cache/incoming/1')
        .create(recursive: true);
  });
  tearDown(() => f.tearDown());

  /// A file as the platform hands it over: copied into the cache.
  Future<String> shared(
    WidgetTester tester,
    String name,
  ) async => (await tester.runAsync(() async {
    final copy = File('${cache.path}/$name');
    await File(
      '${Directory.current.path}/../../test/fixtures/Invoice INV-2026-014.pdf',
    ).copy(copy.path);
    return copy.path;
  }))!;

  /// Starts [openIncoming] as the app does, and lets its file work run.
  Future<void> receive(
    WidgetTester tester,
    GoRouter router,
    IncomingBatch batch,
  ) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    var done = false;
    unawaited(
      openIncoming(container, router, batch).whenComplete(() => done = true),
    );
    // Real file work: give it real time until the sheet or V1 is up.
    for (var i = 0; i < 20 && !done; i++) {
      await settle(tester);
      if (find.text('All tools').evaluate().isNotEmpty) break;
    }
  }

  testWidgets('one shared PDF: X1 with that file, copied into Dokulo', (
    tester,
  ) async {
    final path = await shared(tester, 'Rechnung.pdf');
    final router = await pumpFiles(tester, f, location: Routes.home);
    await receive(tester, router, (view: false, paths: [path]));
    expect(find.text('Rechnung.pdf'), findsWidgets); // the picker's header
    expect(find.text('Open in viewer'), findsOneWidget);
    expect(find.widgetWithText(DkToolRow, 'Compress PDF'), findsOneWidget);
    final rows = await tester.runAsync(() => f.db.select(f.db.files).get());
    expect(rows!.single.path, startsWith(f.store.userFolder.path));
    // The cache copy is gone.
    expect(File(path).existsSync(), isFalse);
  });

  testWidgets('four shared images: X1 with the tools that take them', (
    tester,
  ) async {
    final paths = [
      for (var i = 1; i <= 4; i++) await shared(tester, 'IMG_$i.jpg'),
    ];
    final router = await pumpFiles(tester, f, location: Routes.home);
    await receive(tester, router, (view: false, paths: paths));
    expect(find.text('4 files'), findsOneWidget);
    expect(find.text('4 images'), findsOneWidget);
    expect(find.widgetWithText(DkToolRow, 'Image to PDF'), findsOneWidget);
    expect(find.widgetWithText(DkToolRow, 'Compress PDF'), findsNothing);
    expect(find.text('Open in viewer'), findsNothing);
  });

  testWidgets('"Open with" on a PDF opens V1', (tester) async {
    final path = await shared(tester, 'Vertrag.pdf');
    final router = await pumpFiles(tester, f, location: Routes.home);
    await receive(tester, router, (view: true, paths: [path]));
    final id = (await tester.runAsync(
      () => f.db.select(f.db.files).getSingle(),
    ))!.id;
    expect(router.state.uri.path, Routes.viewer('$id'));
  });
}
