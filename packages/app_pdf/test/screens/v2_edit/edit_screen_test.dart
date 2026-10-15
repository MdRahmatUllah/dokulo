import 'dart:io';

import 'package:app_pdf/screens/v2_edit/annotation_editor.dart' show EditTool;
import 'package:app_pdf/screens/v2_edit/form_layer.dart';
import 'package:app_pdf/components/dk_editor_bars.dart';
import 'package:app_pdf/components/dk_top_bar.dart';
import 'package:app_pdf/components/dk_text_action.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/file_providers.dart';
import 'package:app_pdf/providers/files_providers.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
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
  late Prefs prefs;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dk_v2_');
    db = DokuloDatabase.memory();
    prefs = Prefs.memory();
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
    EditTool? startTool,
    String source = 'Invoice INV-2026-014.pdf',
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
        fixture(source),
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
          builder: (_, _) =>
              EditScreen(fileId: id, fromSign: fromSign, startTool: startTool),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          fileStoreProvider.overrideWith((ref) async => store),
          prefsProvider.overrideWith(() => prefs),
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

  testWidgets('Mark up opens V2 with the highlighter selected (DK-0517)', (
    tester,
  ) async {
    await pump(tester, startTool: EditTool.highlighter);
    expect(
      tester.widget<DkToolStrip>(find.byType(DkToolStrip)).selected,
      2,
      reason: 'Pan, Pen, Highlighter',
    );
  });

  testWidgets('a form: fields tinted; a checkbox toggles, a text field '
      'takes text on the page; Done fills the file (DK-0324)', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, source: 'form-acroform.pdf');
    await settle(tester);
    expect(find.byType(FormLayer), findsWidgets);
    await tester.tap(find.bySemanticsLabel('consent'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Jürgen Groß');
    await tester.tap(find.text('Done'));
    await settle(tester);
    final fields = await tester.runAsync(() => PdfForms.fields(path));
    String value(String name) =>
        fields!.firstWhere((f) => f.name == name).value;
    expect(value('name'), 'Jürgen Groß');
    expect(fields!.firstWhere((f) => f.name == 'consent').checked, isTrue);
    semantics.dispose();
  });

  group('tool options (DK-0314..DK-0320)', () {
    Offset centre(WidgetTester tester) =>
        tester.getCenter(find.byType(PdfViewer));

    Future<void> drag(WidgetTester tester, Offset by) async {
      final g = await tester.startGesture(centre(tester));
      for (var i = 0; i < 10; i++) {
        await g.moveBy(by / 10);
        await tester.pump();
      }
      await g.up();
      await tester.pump();
    }

    testWidgets('a second tap on Pen opens its options; they are remembered', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      await tester.tap(find.text('Pen'));
      await tester.pump();
      await tester.tap(find.text('Pen'));
      await tester.pumpAndSettle();
      expect(find.text('Thickness'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Red'));
      await tester.pumpAndSettle();
      expect(
        prefs.state.value!['edit.options.pen'],
        isNull,
        reason: 'written once the sheet closes',
      );
      Navigator.of(tester.element(find.text('Thickness'))).pop();
      await tester.pumpAndSettle();
      final saved = prefs.state.value!['edit.options.pen'] as Map;
      expect(Color(saved['color'] as int), DkTokens.light.markup.red);
      semantics.dispose();
    });

    testWidgets('a second tap on Pan opens nothing', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Pan'));
      await tester.pump();
      await tester.tap(find.text('Pan'));
      await tester.pumpAndSettle();
      expect(find.text('Thickness'), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('options kept with the wrong types or out of range: defaults '
        'and limits, no crash', (tester) async {
      prefs = Prefs.memory({
        'edit.options.pen': {'thickness': 'thick', 'color': 'red'},
        'edit.options.text': {'fontSize': 200.0},
      });
      await pump(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Pen'));
      await tester.pump();
      await tester.tap(find.text('Pen'));
      await tester.pumpAndSettle();
      expect(find.text('Thickness'), findsOneWidget);
    });

    testWidgets('Shapes: an arrow is ink, the shaft and two barbs', (
      tester,
    ) async {
      await pump(tester);
      await tester.scrollUntilVisible(
        find.text('Shapes'),
        60,
        scrollable: find
            .descendant(
              of: find.byType(DkToolStrip),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shapes'));
      await tester.pump();
      await tester.tap(find.text('Shapes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arrow'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Arrow'))).pop();
      await tester.pumpAndSettle();
      await drag(tester, const Offset(80, 40));
      await tester.tap(find.text('Done'));
      await settle(tester);
      final annots = await tester.runAsync(() => PdfAnnotations.read(path, 0));
      final ink = annots!.map((a) => a.annot).whereType<InkAnnot>().single;
      expect(ink.strokes, hasLength(3));
    });

    testWidgets('Text: a tap places a box and asks for its text', (
      tester,
    ) async {
      await pump(tester);
      await tester.ensureVisible(find.text('Text'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Text'));
      await tester.pump();
      await tester.tapAt(centre(tester));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'Bezahlt');
      await tester.tap(find.text('Done').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await settle(tester);
      final annots = await tester.runAsync(() => PdfAnnotations.read(path, 0));
      expect(
        annots!.map((a) => a.annot).whereType<FreeTextAnnot>().single.text,
        'Bezahlt',
      );
    });

    testWidgets('Text: a box left empty goes again; nothing to save', (
      tester,
    ) async {
      await pump(tester);
      await tester.ensureVisible(find.text('Text'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Text'));
      await tester.pump();
      await tester.tapAt(centre(tester));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done').last);
      await tester.pumpAndSettle();
      final done = tester.widget<DkTextAction>(
        find.widgetWithText(DkTextAction, 'Done'),
      );
      expect(done.onTap, isNull, reason: 'no changes');
    });
  });
}
