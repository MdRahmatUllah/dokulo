import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/patterns/dk_tool_picker.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/files_providers.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

FileEntry entry(int id, String name, {int pages = 12}) => FileEntry(
  id: id,
  path: '/nowhere/$name',
  name: name,
  size: 2400000,
  pages: pages,
  created: DateTime(2026),
  modified: DateTime(2026),
  hasText: true,
  encrypted: false,
);

void main() {
  late List<String> pushed;

  Future<void> open(
    WidgetTester tester,
    List<FileEntry> files, {
    DkTokens? tokens,
    Locale locale = const Locale('en'),
  }) async {
    pushed = [];
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = DokuloDatabase.memory();
    addTearDown(db.close);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showToolPicker(context, files),
                child: const Text('share'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/tool/:id',
          builder: (_, s) {
            pushed.add(s.uri.toString());
            return const Text('T2');
          },
        ),
        GoRoute(
          path: '/viewer/:id',
          builder: (_, s) {
            pushed.add(s.uri.toString());
            return const Text('V1');
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          pinnedToolsProvider.overrideWith(
            (ref) => Stream.value(defaultPinnedTools),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          theme: dokuloTheme(tokens ?? DkTokens.light),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.tap(find.text('share'));
    await tester.pumpAndSettle();
  }

  testWidgets('one PDF (DK-1094): its name, Open in viewer, Suggested from '
      'the pinned tools that fit, no Merge; a tool opens T2 with the file', (
    tester,
  ) async {
    await open(tester, [entry(7, 'Mietvertrag.pdf')]);
    expect(find.text('Mietvertrag.pdf'), findsOneWidget);
    expect(find.text('Open in viewer'), findsOneWidget);
    expect(find.text('Suggested'), findsOneWidget);
    expect(find.text('Compress PDF'), findsOneWidget);
    expect(find.text('Merge PDF'), findsNothing, reason: 'needs 2 files');
    expect(find.text('Image to PDF'), findsNothing, reason: 'takes images');
    await tester.tap(find.text('Compress PDF'));
    await tester.pumpAndSettle();
    expect(pushed.single, startsWith('/tool/compress'));
    expect(pushed.single, contains('7'));
  });

  testWidgets('four photos: "4 files", only the tools that take them', (
    tester,
  ) async {
    await open(tester, [
      for (var i = 1; i <= 4; i++) entry(i, 'IMG_$i.jpg', pages: 0),
    ]);
    expect(find.text('4 files'), findsOneWidget);
    expect(find.text('Open in viewer'), findsNothing);
    expect(find.text('Image to PDF'), findsOneWidget);
    expect(find.text('Compress PDF'), findsNothing);
  });

  testWidgets('search narrows the list', (tester) async {
    await open(tester, [entry(7, 'Mietvertrag.pdf')]);
    await tester.enterText(find.byType(TextField), 'password');
    await tester.pumpAndSettle();
    expect(find.text('Add password'), findsOneWidget);
    expect(find.text('Compress PDF'), findsNothing);
    expect(find.text('Suggested'), findsNothing);
  });

  test('compatibleTools: kind and count', () {
    final one = compatibleTools([entry(1, 'a.pdf')]).map((t) => t.id);
    expect(one, containsAll(['compress', 'protect', 'ocr']));
    expect(one, isNot(contains('merge')));
    final two = compatibleTools([entry(1, 'a.pdf'), entry(2, 'b.pdf')]);
    expect(two.map((t) => t.id), contains('merge'));
  });

  // Visual QA (DK-1094, DK-0848): the x1single frame in each theme and in
  // German; the frames are in docs/qa/tool-shell/.
  for (final (theme, tokens, locale) in [
    ('light', DkTokens.light, const Locale('en')),
    ('dark', DkTokens.dark, const Locale('en')),
    ('deutsch', DkTokens.light, const Locale('de')),
  ]) {
    testWidgets('golden: tool_shell_x1single_$theme', (tester) async {
      await open(
        tester,
        [entry(7, 'Mietvertrag Musterstraße 12.pdf')],
        tokens: tokens,
        locale: locale,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../qa/goldens/tool_shell_x1single_$theme.png'),
      );
    });
  }
}
