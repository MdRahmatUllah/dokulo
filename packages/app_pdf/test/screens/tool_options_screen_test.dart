import 'package:app_pdf/components/dk_action_bar.dart';
import 'package:app_pdf/components/dk_segmented.dart';
import 'package:app_pdf/components/dk_switch.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_providers.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/tools/tool_definition.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A tool as its own task would declare it: one option of each kind.
final _compress = ToolDefinition(
  id: 'compress',
  options: [
    ToolSegments<String>(
      key: 'level',
      title: (_) => 'Level',
      values: const ['light', 'recommended', 'strong'],
      label: (_, v) => v,
      initial: 'recommended',
    ),
    ToolCustom(
      key: 'target',
      title: (_) => 'Target size',
      initial: null,
      builder: (context, subject, value, onChanged) => TextButton(
        onPressed: () => onChanged('2 MB'),
        child: Text('target: ${value ?? 'none'} of ${subject.pages} pages'),
      ),
    ),
  ],
  moreOptions: [ToolSwitch(key: 'grey', title: (_) => 'Greyscale')],
  action: (l, s) => 'Compress ${s.pages} pages',
  estimate: (l, s, v) => 'About 1.9 MB · ${v['level']}',
  input: (s, v, env) => v,
);

void main() {
  late DokuloDatabase db;
  late List<int> ids;
  late ProviderContainer container;

  setUp(() async {
    db = DokuloDatabase.memory();
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> addFiles(WidgetTester tester, List<(String, int)> files) async {
    ids = [];
    for (final (name, pages) in files) {
      await tester.runAsync(() async {
        final id = await db
            .into(db.files)
            .insert(
              FilesCompanion.insert(
                path: name,
                name: name,
                size: 2400000,
                created: DateTime(2026),
                modified: DateTime(2026),
              ),
            );
        await db.customStatement('UPDATE files SET pages = ? WHERE id = ?', [
          pages,
          id,
        ]);
        ids.add(id);
      });
    }
  }

  Future<void> pump(
    WidgetTester tester,
    ToolDefinition def, {
    DkTokens? tokens,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dokuloTheme(tokens ?? DkTokens.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ToolOptionsScreen(definition: def, fileIds: ids),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  }

  DkActionBar bar(WidgetTester tester) =>
      tester.widget<DkActionBar>(find.byType(DkActionBar));

  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('golden: tool_options_$theme, two files and options', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await addFiles(tester, [('Anschreiben.pdf', 1), ('Zeugnisse.pdf', 34)]);
      await pump(tester, _compress, tokens: tokens);
      await expectLater(
        find.byType(ToolOptionsScreen),
        matchesGoldenFile('goldens/tool_options_$theme.png'),
      );
    });
  }

  testWidgets('renders the declared options, the action with the number, '
      'and the estimate; More options holds the rest', (tester) async {
    tester.view.physicalSize = const Size(393, 852); // a phone
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await addFiles(tester, [('Mietvertrag.pdf', 12)]);
    await pump(tester, _compress);
    expect(find.text('Compress PDF'), findsOneWidget, reason: 'the title');
    expect(find.text('Processed on this phone'), findsOneWidget);
    expect(find.text('File'), findsOneWidget);
    expect(find.text('Mietvertrag.pdf'), findsOneWidget);
    expect(find.text('Options'), findsOneWidget);
    expect(find.byType(DkSegmented<Object>), findsOneWidget);
    expect(find.text('target: none of 12 pages'), findsOneWidget);
    expect(find.text('Greyscale'), findsNothing, reason: 'behind More options');
    expect(bar(tester).label, 'Compress 12 pages');
    expect(bar(tester).caption, 'About 1.9 MB · recommended');
    expect(bar(tester).onPressed, isNotNull);

    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    expect(find.byType(DkSwitch), findsOneWidget);
  });

  testWidgets('options persist when going back and opening the tool again; '
      'Reset options clears them', (tester) async {
    await addFiles(tester, [('a.pdf', 3)]);
    await pump(tester, _compress);
    await tester.tap(find.text('strong'));
    await tester.tap(find.text('target: none of 3 pages'));
    await tester.pump();
    expect(bar(tester).caption, 'About 1.9 MB · strong');

    // Back, then the tool again: a new screen, the same choices.
    await tester.pumpWidget(const SizedBox());
    await pump(tester, _compress);
    expect(bar(tester).caption, 'About 1.9 MB · strong');
    expect(find.text('target: 2 MB of 3 pages'), findsOneWidget);

    container.read(toolOptionValuesProvider('compress').notifier).reset();
    await tester.pump();
    expect(bar(tester).caption, 'About 1.9 MB · recommended');
  });

  testWidgets('several files: "Files (3)", remove one, reorder by the handle', (
    tester,
  ) async {
    await addFiles(tester, [('a.pdf', 1), ('b.pdf', 2), ('c.pdf', 4)]);
    await pump(tester, _compress);
    expect(find.text('Files (3)'), findsOneWidget);
    expect(bar(tester).label, 'Compress 7 pages');

    await tester.tap(find.byTooltip('Remove b.pdf'));
    await tester.pump();
    expect(find.text('Files (2)'), findsOneWidget);
    expect(find.text('b.pdf'), findsNothing);
    expect(bar(tester).label, 'Compress 5 pages');

    // c.pdf above a.pdf.
    final handle = find.byType(ReorderableDragStartListener).last;
    final drag = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await drag.moveBy(const Offset(0, -12));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('c.pdf')).dy,
      lessThan(tester.getTopLeft(find.text('a.pdf')).dy),
    );
  });

  testWidgets('a tool without its definition yet shows its name on a '
      'disabled button', (tester) async {
    await addFiles(tester, [('a.pdf', 1)]);
    await pump(tester, const ToolDefinition(id: 'split'));
    expect(find.text('Options'), findsNothing);
    expect(bar(tester).label, 'Split PDF');
    expect(bar(tester).onPressed, isNull);
  });

  testWidgets('screen readers: a heading per section, and the main action '
      'is the last thing they reach', (tester) async {
    final semantics = tester.ensureSemantics();
    await addFiles(tester, [('a.pdf', 1)]);
    await pump(tester, _compress);
    for (final h in ['File', 'Options']) {
      expect(
        tester.getSemantics(find.text(h)),
        isSemantics(label: h, isHeader: true),
      );
    }
    // Everything a screen reader can activate, in tree order.
    final order = <SemanticsNode>[];
    void visit(SemanticsNode n) {
      if (n.getSemanticsData().hasAction(SemanticsAction.tap)) order.add(n);
      n.visitChildren((c) {
        visit(c);
        return true;
      });
    }

    visit(tester.getSemantics(find.byType(ToolOptionsScreen)));
    expect(order.last.label, contains('Compress 1 pages'));
    semantics.dispose();
  });
}
