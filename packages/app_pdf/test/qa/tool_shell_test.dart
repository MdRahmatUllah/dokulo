import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/file_providers.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_screen.dart';
import 'package:app_pdf/screens/t2_tool/tool_run.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/tools/tool_definition.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

// Visual QA (DK-0838, DK-0842, DK-0843, DK-0844, DK-0847): the T2 and X2
// frames of 12-tool-shell (t2empty, lockedrow, btnloading, progress,
// failure), rendered by the real T2 in each state at 393 × 852. The goldens
// sit next to the frames' screenshots in docs/qa/tool-shell/; the findings
// are in docs/qa/design-system.md. A tool's own options (Compress's levels)
// come with its task (DK-0463), so the boards show the shell.

String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

final _compress = ToolDefinition(
  id: 'compress',
  action: (l, s) => 'Compress ${s.pages} pages',
  busyLabel: (l) => 'Compressing…',
  busyTitle: (l, s) => 'Compressing ${s.files.first.name}',
  input: (s, v, env) => v,
);

final _merge = ToolDefinition(
  id: 'merge',
  action: (l, s) => 'Merge ${s.files.length} files',
  input: (s, v, env) => v,
);

/// A 1 × 1 grey PNG: a photo for the board (an image decodes by content).
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

class _Run {
  final progress = StreamController<JobProgress>.broadcast();
  final result = Completer<Object?>();

  ToolRunHandle get handle => (
    progress: progress.stream,
    result: result.future,
    cancel: () {},
    discard: () async {},
  );
}

void main() {
  setUpAll(pdfrxInitialize);
  final sep = Platform.pathSeparator;
  late Directory root;
  late DokuloDatabase db;
  late FileStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dk_qa_t2_');
    db = DokuloDatabase.memory();
    store = FileStore(
      userFolder: Directory('${root.path}${sep}Dokulo'),
      workDirectory: Directory('${root.path}${sep}sandbox'),
    );
  });
  tearDown(() async {
    await db.close();
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // A decoder still holding a file on Windows: the OS cleans temp.
    }
  });

  /// A file of the frame's, from [source], with the frame's size and pages.
  Future<int> file(
    WidgetTester tester,
    String name, {
    String source = 'Invoice INV-2026-014.pdf',
    int size = 1000,
    int pages = 1,
    DateTime? modified,
    List<int>? bytes,
  }) async => (await tester.runAsync(() async {
    final f = File('${store.userFolder.path}$sep$name')
      ..parent.createSync(recursive: true);
    if (bytes != null) {
      await f.writeAsBytes(bytes);
    } else {
      await File(fixture(source)).copy(f.path);
    }
    final id = await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            path: f.path,
            name: name,
            size: size,
            created: DateTime(2026),
            modified: modified ?? DateTime(2026, 10, 1),
          ),
        );
    await db.customStatement('UPDATE files SET pages = ? WHERE id = ?', [
      pages,
      id,
    ]);
    return id;
  }))!;

  Future<void> pump(
    WidgetTester tester,
    DkTokens tokens,
    ToolDefinition def,
    List<int> ids, {
    _Run? run,
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          fileStoreProvider.overrideWith((ref) async => store),
          if (run != null)
            toolRunnerProvider.overrideWithValue(
              (id, input) async => run.handle,
            ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dokuloTheme(tokens),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ToolOptionsScreen(definition: def, fileIds: ids),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> golden(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/tool_shell_$name.png'),
  );

  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('t2empty, $theme: "Choose a PDF", the recent PDFs, Browse '
        'device; the button waits', (tester) async {
      var day = 9;
      for (final (name, size, pages) in [
        ('Mietvertrag Musterstraße 12.pdf', 8400000, 12),
        ('Invoice INV-2026-014.pdf', 186000, 2),
        ('Finanzamt München – Bescheid 2025.pdf', 640000, 4),
        ('Whiteboard notes.pdf', 3200000, 1),
        ('Lebenslauf Max Mustermann.pdf', 412000, 2),
      ]) {
        await file(
          tester,
          name,
          size: size,
          pages: pages,
          modified: DateTime(2026, 10, day--),
        );
      }
      await pump(tester, tokens, _compress, const []);
      await golden(tester, 't2empty_$theme');
    });

    testWidgets('lockedrow, $theme: four files, the locked one with its '
        'unlock row', (tester) async {
      final ids = [
        await file(tester, 'Anschreiben.pdf'),
        await file(tester, 'Lebenslauf Max Mustermann.pdf', pages: 2),
        await file(
          tester,
          'Zeugnisse.pdf',
          source: 'encrypted-aes256.pdf',
          pages: 34,
        ),
        await file(tester, 'Personalausweis.jpg', bytes: _png),
      ];
      await pump(tester, tokens, _merge, ids);
      await golden(tester, 'lockedrow_$theme');
    });

    testWidgets('btnloading, $theme: "Compressing…" after 2 s', (tester) async {
      final id = await file(
        tester,
        'Mietvertrag Musterstraße 12.pdf',
        size: 8400000,
        pages: 12,
      );
      final run = _Run();
      await pump(tester, tokens, _compress, [id], run: run);
      await tester.tap(find.text('Compress 12 pages'));
      await tester.pump(const Duration(seconds: 3));
      await golden(tester, 'btnloading_$theme');
      run.result.complete(null);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('progress, $theme: the sheet after 10 s', (tester) async {
      final id = await file(
        tester,
        'Mietvertrag.pdf',
        size: 8400000,
        pages: 12,
      );
      final run = _Run();
      await pump(tester, tokens, _compress, [id], run: run);
      await tester.tap(find.text('Compress 12 pages'));
      await tester.pump(const Duration(seconds: 3));
      run.progress.add(
        const JobProgress(
          'reading',
          pageIndex: 17,
          pageCount: 40,
          etaSeconds: 20,
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await golden(tester, 'progress_$theme');
      run.result.complete(null);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('failure, $theme: the error state with its code line', (
      tester,
    ) async {
      final id = await file(
        tester,
        'Mietvertrag Musterstraße 12.pdf',
        size: 8400000,
        pages: 12,
      );
      final run = _Run();
      await pump(tester, tokens, _compress, [id], run: run);
      await tester.tap(find.text('Compress 12 pages'));
      await tester.pump();
      run.result.completeError(
        const DocError(DocErrorKind.unexpected, page: 13),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.text('Something went wrong on page 14.'), findsOneWidget);
      expect(find.text('Code DK-0190'), findsOneWidget);
      await golden(tester, 'failure_$theme');
    });
  }
}

/// The database, the lock check (PDFium) and the thumbnails between frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}
