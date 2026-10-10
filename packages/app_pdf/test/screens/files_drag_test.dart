import 'dart:io';

import 'package:app_pdf/components/dk_file_card.dart';
import 'package:app_pdf/components/dk_folder_card.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'files_screen_test.dart' show FilesFixture, pumpFiles, settle;

/// Grid view: drag a file onto a folder card (DK-0264).
void main() {
  late FilesFixture f;
  setUp(() async {
    f = FilesFixture();
    await f.setUp();
  });
  tearDown(() => f.tearDown());

  testWidgets('drop on a folder: the ring while over it, moved, Undo', (
    tester,
  ) async {
    late int taxes, id;
    await tester.runAsync(() async {
      taxes = await f.store.createFolder(f.db, 'Taxes');
      final pdf = File('${f.root.path}/Dokulo/Bescheid.pdf')
        ..createSync(recursive: true)
        ..writeAsStringSync('%PDF');
      id = await f.db
          .into(f.db.files)
          .insert(
            FilesCompanion.insert(
              path: pdf.path,
              name: 'Bescheid.pdf',
              size: 4,
              created: DateTime(2026, 10, 1),
              modified: DateTime(2026, 10, 1),
            ),
          );
    });
    f.prefs['files.grid'] = true;
    await pumpFiles(tester, f);

    // As pinned_tools_test: the long press on the real clock.
    late TestGesture g;
    final target = tester.getCenter(find.text('Taxes'));
    await tester.runAsync(() async {
      // Near the card's top: its middle is under the tab bar.
      g = await tester.startGesture(
        tester.getTopLeft(find.byType(DkFileCard)) + const Offset(60, 40),
      );
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      await g.moveBy(const Offset(0, -8));
      await tester.pump();
      await g.moveTo(target);
      await tester.pump();
      await g.moveBy(const Offset(1, 1));
      await tester.pump();
    });
    expect(
      tester.widget<DkFolderCard>(find.byType(DkFolderCard)).dropTarget,
      isTrue,
      reason: 'the ring',
    );
    await tester.runAsync(() async {
      await g.up();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(find.text('Moved to Taxes'), findsOneWidget);
    final row = await tester.runAsync(
      () =>
          (f.db.select(f.db.files)..where((r) => r.id.equals(id))).getSingle(),
    );
    expect(row!.folderId, taxes);
    expect(
      File('${f.root.path}/Dokulo/Taxes/Bescheid.pdf').existsSync(),
      isTrue,
    );

    await tester.runAsync(() async {
      await tester.tap(find.text('Undo'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    expect(File('${f.root.path}/Dokulo/Bescheid.pdf').existsSync(), isTrue);
  });
}
