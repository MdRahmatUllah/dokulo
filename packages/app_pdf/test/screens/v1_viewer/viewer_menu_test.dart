import 'dart:io';

import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/file_providers.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/providers/print_providers.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_screen.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_thumb_strip.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import '../viewer_screen_test.dart' show fixture, settle;

// The overflow menu (DK-0295; UI spec §17.1, viewer-menu).
void main() {
  setUpAll(pdfrxInitialize);
  late Directory root;
  late DokuloDatabase db;
  late FileStore store;
  late Map<String, Object?> prefs;
  late List<String> printed;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dk_v1_menu_');
    db = DokuloDatabase.memory();
    store = FileStore(
      userFolder: Directory('${root.path}/Dokulo'),
      workDirectory: Directory('${root.path}/work'),
    );
    prefs = {};
    printed = [];
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views;
    view.first
      ..physicalSize = const Size(393, 852)
      ..devicePixelRatio = 1;
  });
  tearDown(() async {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset();
    await db.close();
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // PDFium may still hold the file on Windows: the OS cleans temp.
    }
  });

  /// V1 on a copy of the 12-page lease, pushed over a page that says
  /// "beneath" (Delete closes V1 back to it); the menu open.
  Future<int> openMenu(WidgetTester tester) async {
    final id = (await tester.runAsync(() async {
      Directory('${root.path}/Dokulo').createSync(recursive: true);
      final copy = await File(fixture('Mietvertrag Musterstraße 12.pdf'))
          .copy('${root.path}/Dokulo/Mietvertrag.pdf');
      return db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              path: copy.path,
              name: 'Mietvertrag.pdf',
              size: 1,
              created: DateTime(2026),
              modified: DateTime(2026),
            ),
          );
    }))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          fileStoreProvider.overrideWith((ref) async => store),
          prefsProvider.overrideWith(() => Prefs.memory(prefs)),
          pdfPrinterProvider.overrideWithValue((path, name) async {
            printed.add(name);
            return true;
          }),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dokuloTheme(DkTokens.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ViewerScreen(fileId: id),
                  ),
                ),
                child: const Text('beneath'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('beneath'));
    await settle(tester);
    await tester.tap(find.byTooltip('More'));
    await settle(tester, rounds: 5);
    return id;
  }

  testWidgets('the frame\'s items in order, Delete last', (tester) async {
    await openMenu(tester);
    final labels = [
      'Info',
      'Go to page',
      'Pages',
      'Night mode',
      'Organize pages',
      'Print',
      'Move to locked folder',
      'Delete',
    ];
    final tops = [
      for (final l in labels) tester.getTopLeft(find.text(l).last).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
  });

  testWidgets('Night mode switches the pages', (tester) async {
    await openMenu(tester);
    await tester.tap(find.text('Night mode'));
    await settle(tester, rounds: 5);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ViewerScreen)),
    );
    expect(container.read(prefsProvider).value?[viewerNightKey], isTrue);
    expect(find.byType(ColorFiltered), findsOneWidget);
  });

  testWidgets('Pages shows the thumbnail strip', (tester) async {
    await openMenu(tester);
    expect(find.byType(ViewerThumbStrip), findsNothing);
    await tester.tap(find.text('Pages'));
    await settle(tester, rounds: 5);
    expect(find.byType(ViewerThumbStrip), findsOneWidget);
  });

  testWidgets('Print hands the file to the system dialog', (tester) async {
    await openMenu(tester);
    await tester.tap(find.text('Print'));
    await settle(tester, rounds: 5);
    expect(printed, ['Mietvertrag.pdf']);
  });

  testWidgets('Delete: to Recently deleted with Undo, and V1 closes', (
    tester,
  ) async {
    final id = await openMenu(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester, rounds: 10);
    expect(find.byType(ViewerScreen), findsNothing);
    expect(find.text('Undo'), findsOneWidget);
    final trashed = await tester.runAsync(() => db.select(db.trash).get());
    expect(trashed!.single.fileId, id);
  });
}
