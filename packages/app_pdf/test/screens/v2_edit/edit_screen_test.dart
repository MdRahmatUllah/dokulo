import 'dart:io';

import 'package:app_pdf/components/dk_top_bar.dart';
import 'package:app_pdf/components/dk_text_action.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/file_providers.dart';
import 'package:app_pdf/providers/files_providers.dart';
import 'package:app_pdf/providers/signature_providers.dart';
import 'package:app_pdf/screens/v2_edit/edit_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';

String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

Future<void> settle(WidgetTester tester, {int rounds = 30}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(pdfrxInitialize);
  late Directory root;
  late DokuloDatabase db;
  late String path;
  late int id;
  late GoRouter router;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dk_v2_');
    db = DokuloDatabase.memory();
  });
  tearDown(() async {
    await db.close();
    // PDFium may still hold the file open (Windows): leave it to the OS.
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // ignore
    }
  });

  Future<void> pump(
    WidgetTester tester, {
    DkTokens? tokens,
    bool fromSign = false,
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = FileStore(
      userFolder: Directory('${root.path}/Dokulo'),
      workDirectory: Directory('${root.path}/work'),
    );
    await tester.runAsync(() async {
      store.userFolder.createSync(recursive: true);
      Directory('${root.path}/versions').createSync();
      path = (await File(
        fixture('Invoice INV-2026-014.pdf'),
      ).copy('${store.userFolder.path}/Invoice.pdf')).path;
      id = await db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              path: path,
              name: 'Invoice.pdf',
              size: File(path).lengthSync(),
              created: DateTime(2026),
              modified: DateTime(2026),
            ),
          );
    });
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('V1')),
        GoRoute(
          path: '/edit',
          builder: (_, _) => EditScreen(fileId: id, fromSign: fromSign),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          fileStoreProvider.overrideWith((ref) async => store),
          signatureStoreProvider.overrideWith(
            (ref) async => SignatureStore(
              db,
              Directory('${root.path}/signatures'),
              LockedCipher(List.filled(32, 1)),
            ),
          ),
          versionStoreProvider.overrideWith(
            (ref) async => VersionStore(db, Directory('${root.path}/versions')),
          ),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: dokuloTheme(tokens ?? DkTokens.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    router.push('/edit');
    await settle(tester);
  }

  DkTextAction done(WidgetTester tester) => tester.widget<DkTextAction>(
    find.descendant(
      of: find.byType(DkTopBar),
      matching: find.widgetWithText(DkTextAction, 'Done'),
    ),
  );

  Future<void> draw(WidgetTester tester) async {
    await tester.tap(find.text('Pen'));
    await tester.pump();
    final centre = tester.getCenter(find.byType(PdfViewer));
    final g = await tester.startGesture(centre);
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(8, 4));
      await tester.pump();
    }
    await g.up();
    await tester.pump();
  }

  testWidgets('the editing bar, the strip; Done off until something changes; '
      'Cancel without changes just leaves', (tester) async {
    await pump(tester);
    expect(find.text('Editing'), findsOneWidget);
    // The strip scrolls sideways: the first ones are on screen.
    for (final tool in ['Pan', 'Pen', 'Highlighter']) {
      expect(find.text(tool), findsOneWidget);
    }
    expect(done(tester).onTap, isNull);
    await tester.tap(find.text('Cancel'));
    await settle(tester, rounds: 5);
    expect(find.text('V1'), findsOneWidget);
  });

  testWidgets('drawing with Pen: Cancel asks "Discard your changes?"', (
    tester,
  ) async {
    await pump(tester);
    await draw(tester);
    expect(done(tester).onTap, isNotNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard your changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Editing'), findsOneWidget);
  });

  testWidgets('Done writes the ink into the file and keeps a version', (
    tester,
  ) async {
    await pump(tester);
    await draw(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text('V1'), findsOneWidget);
    final annots = await tester.runAsync(() => PdfAnnotations.read(path, 0));
    expect(annots!.whereType<PageAnnot>(), isNotEmpty);
    final versions = await tester.runAsync(
      () => VersionStore(db, Directory('${root.path}/versions')).list(id),
    );
    expect(versions, hasLength(1));
  });

  testWidgets('a file that is gone says so', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: dokuloTheme(DkTokens.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const EditScreen(fileId: 404),
        ),
      ),
    );
    await settle(tester, rounds: 5);
    expect(find.text("This file isn't in Dokulo any more."), findsOneWidget);
  });

  testWidgets('entered from Sign: Pan, and the signatures sheet opens', (
    tester,
  ) async {
    await pump(tester, fromSign: true);
    await settle(tester, rounds: 10);
    expect(find.text('Your signatures'), findsOneWidget);
  });

  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('golden: edit mode with Pen ($name)', (tester) async {
      await pump(tester, tokens: tokens);
      await tester.tap(find.text('Pen'));
      await settle(tester, rounds: 5);
      await expectLater(
        find.byType(EditScreen),
        matchesGoldenFile('goldens/edit_pen_$name.png'),
      );
    });
  }
}
