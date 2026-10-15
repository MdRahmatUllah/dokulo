import 'dart:io';

import 'package:app_pdf/components/dk_action_bar.dart';
import 'package:app_pdf/components/dk_file_card.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/file_providers.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_providers.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/tools/tool_definition.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

/// T2's input (DK-0371 picker, DK-0372 locked files, DK-0373 estimate).
void main() {
  setUpAll(pdfrxInitialize);
  final sep = Platform.pathSeparator;
  late Directory root;
  late FileStore store;
  late DokuloDatabase db;
  late List<String> devicePicks;
  ToolSubject? lastSubject;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dk_t2in_');
    store = FileStore(
      userFolder: Directory('${root.path}${sep}Dokulo'),
      workDirectory: Directory('${root.path}${sep}sandbox'),
    );
    db = DokuloDatabase.memory();
    devicePicks = [];
    lastSubject = null;
  });
  tearDown(() async {
    await db.close();
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // A decoder still holding a file on Windows: the OS cleans temp.
    }
  });

  ToolDefinition def(String id) => ToolDefinition(
    id: id,
    estimate: (l, s, v) {
      lastSubject = s;
      return 'About ${s.pages} pages';
    },
    input: (s, v, env) => v,
  );

  Future<int> addFile(
    WidgetTester tester,
    String name, {
    String? from,
    DateTime? modified,
  }) async => (await tester.runAsync(() async {
    final file = File('${store.userFolder.path}$sep$name')
      ..parent.createSync(recursive: true);
    if (from != null) {
      await File(fixture(from)).copy(file.path);
    } else {
      file.writeAsStringSync('x');
    }
    return db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            path: file.path,
            name: name,
            size: 1000,
            created: DateTime(2026),
            modified: modified ?? DateTime(2026),
          ),
        );
  }))!;

  Future<void> pumpT2(
    WidgetTester tester,
    ToolDefinition definition, {
    List<int> fileIds = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          fileStoreProvider.overrideWith((ref) async => store),
          devicePickerProvider.overrideWithValue(
            (input, {required photos}) async => devicePicks,
          ),
        ],
        child: MaterialApp(
          theme: dokuloTheme(DkTokens.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ToolOptionsScreen(definition: definition, fileIds: fileIds),
        ),
      ),
    );
    await settle(tester);
  }

  DkActionBar bar(WidgetTester tester) =>
      tester.widget<DkActionBar>(find.byType(DkActionBar));

  testWidgets('no input: "Choose a PDF" lists only recent PDFs, the button '
      'waits with "Choose a file to continue"; a tap takes it (DK-0371)', (
    tester,
  ) async {
    await addFile(tester, 'Old.pdf', modified: DateTime(2025));
    await addFile(tester, 'Photo.jpg');
    await addFile(tester, 'New.pdf', modified: DateTime(2026, 5));
    await pumpT2(tester, def('split'));
    expect(find.text('Choose a PDF'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Photo.jpg'), findsNothing, reason: 'not a PDF');
    expect(
      tester.getTopLeft(find.text('New.pdf')).dy,
      lessThan(tester.getTopLeft(find.text('Old.pdf')).dy),
    );
    expect(find.text('Browse device'), findsOneWidget);
    expect(find.text('Choose photos'), findsNothing);
    expect(bar(tester).caption, 'Choose a file to continue');
    expect(bar(tester).onPressed, isNull);

    await tester.tap(find.text('New.pdf'));
    await settle(tester);
    expect(find.text('Choose a PDF'), findsNothing);
    expect(find.text('File'), findsOneWidget);
    expect(bar(tester).onPressed, isNotNull);
  });

  testWidgets('an image tool: "Choose images", Choose photos copies the '
      'picked photo into the sandbox first', (tester) async {
    final photo = File('${root.path}${sep}IMG_0001.jpg')
      ..writeAsStringSync('jpeg');
    devicePicks = [photo.path];
    await pumpT2(tester, def('img2pdf'));
    expect(find.text('Choose images'), findsOneWidget);
    await tester.tap(find.text('Choose photos'));
    await settle(tester);
    expect(find.text('IMG_0001.jpg'), findsOneWidget);
    expect(lastSubject!.files.single.path, startsWith(store.inbox.path));
    expect(photo.existsSync(), isTrue, reason: 'the original stays');
    // Let go of the image file (Windows can't delete an open one).
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Merge needs two: checkboxes until two are chosen', (
    tester,
  ) async {
    await addFile(tester, 'a.pdf');
    await addFile(tester, 'b.pdf');
    await pumpT2(tester, def('merge'));
    expect(find.text('Choose files'), findsOneWidget);
    await tester.tap(find.text('a.pdf'));
    await settle(tester);
    expect(
      tester.widget<DkFileCard>(find.byType(DkFileCard).first).selected,
      isTrue,
    );
    expect(bar(tester).onPressed, isNull);
    await tester.tap(find.text('b.pdf'));
    await settle(tester);
    expect(find.text('Files (2)'), findsOneWidget);
    expect(bar(tester).onPressed, isNotNull);
  });

  testWidgets('arriving with a file skips the picker', (tester) async {
    final id = await addFile(tester, 'Given.pdf');
    await pumpT2(tester, def('split'), fileIds: [id]);
    expect(find.text('Choose a PDF'), findsNothing);
    expect(find.text('Given.pdf'), findsOneWidget);
  });

  testWidgets('a locked input: "This file is locked" until the right '
      'password, kept for this run only (DK-0372)', (tester) async {
    final id = await addFile(
      tester,
      'Locked.pdf',
      from: 'encrypted-aes256.pdf',
    );
    await pumpT2(tester, def('split'), fileIds: [id]);
    expect(find.text('This file is locked'), findsOneWidget);
    expect(bar(tester).caption, 'Unlock Locked.pdf to continue');
    expect(bar(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.tap(find.text('Unlock'));
    await settle(tester);
    expect(find.text("That password doesn't open this file."), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'dokulo');
    await tester.tap(find.text('Unlock'));
    await settle(tester);
    expect(find.text('This file is locked'), findsNothing);
    expect(bar(tester).onPressed, isNotNull);
    expect(lastSubject!.passwordOf(lastSubject!.files.single), 'dokulo');
  });
}

/// Database, file and PDFium work between frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}
