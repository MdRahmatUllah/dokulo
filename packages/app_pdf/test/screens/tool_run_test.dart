import 'dart:async';

import 'package:ai_core/ai_core.dart';
import 'package:app_pdf/components/dk_action_bar.dart';
import 'package:app_pdf/components/dk_progress_sheet.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_providers.dart';
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
import 'package:go_router/go_router.dart';

/// A simulated job: the test reports its progress and ends it.
class _Run {
  final progress = StreamController<JobProgress>.broadcast();
  final result = Completer<Object?>();
  var cancelled = false, discarded = false;

  ToolRunHandle get handle => (
    progress: progress.stream,
    result: result.future,
    cancel: () {
      cancelled = true;
      result.completeError(const JobCancelled());
    },
    discard: () async => discarded = true,
  );
}

final _def = ToolDefinition(
  id: 'compress',
  action: (l, s) => 'Compress ${s.pages} pages',
  busyLabel: (l) => 'Compressing…',
  busyTitle: (l, s) => 'Compressing ${s.files.single.name}',
  stopTitle: (l) => 'Stop compressing?',
  input: (s, v, env) => env.outputDir,
);

/// Sheets and dialogs in, with the spinner still turning (no pumpAndSettle).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  test('the X2 thresholds: nothing under 2 s, the button to 10 s, then the '
      'sheet (UI spec §20.2)', () {
    expect(x2PhaseAt(const Duration(milliseconds: 1999)), X2Phase.quiet);
    expect(x2PhaseAt(const Duration(seconds: 2)), X2Phase.button);
    expect(x2PhaseAt(const Duration(milliseconds: 9999)), X2Phase.button);
    expect(x2PhaseAt(const Duration(seconds: 10)), X2Phase.sheet);
  });

  test('the time left never jumps more than 50 % between updates', () {
    expect(smoothEta(null, 40), 40);
    expect(smoothEta(20, 100), 30);
    expect(smoothEta(20, 2), 10);
    expect(smoothEta(20, 25), 25);
    var shown = 60;
    for (final raw in [5, 5, 5, 5]) {
      final next = smoothEta(shown, raw);
      expect(next, greaterThanOrEqualTo((shown * 0.5).ceil()));
      shown = next;
    }
  });

  late DokuloDatabase db;
  late _Run run;
  late int fileId;

  setUp(() => db = DokuloDatabase.memory());
  tearDown(() => db.close());

  Future<GoRouter> pumpT2(WidgetTester tester) async {
    // In the test's fake-async zone, so its futures complete on pump.
    run = _Run();
    fileId = (await tester.runAsync(
      () => db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              path: 'Mietvertrag.pdf',
              name: 'Mietvertrag.pdf',
              size: 8400000,
              created: DateTime(2026),
              modified: DateTime(2026),
            ),
          ),
    ))!;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              ToolOptionsScreen(definition: _def, fileIds: [fileId]),
        ),
        GoRoute(path: '/tool/:id/result', builder: (_, _) => const Text('T3')),
        GoRoute(
          path: '/tool/:id',
          builder: (_, s) => Text('T2 ${s.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          toolRunnerProvider.overrideWithValue(
            (toolId, input) async => run.handle,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: dokuloTheme(DkTokens.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    return router;
  }

  DkActionBar bar(WidgetTester tester) =>
      tester.widget<DkActionBar>(find.byType(DkActionBar));

  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.text('Compress 0 pages'));
    await tester.pump();
  }

  testWidgets('a job past 10 s: quiet, then "Compressing…", then the sheet '
      'with the smoothed time left; done: T3', (tester) async {
    await pumpT2(tester);
    await start(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(bar(tester).loading, isFalse);
    expect(bar(tester).label, 'Compress 0 pages');

    await tester.pump(const Duration(seconds: 2));
    expect(bar(tester).loading, isTrue);
    expect(bar(tester).label, 'Compressing…');
    expect(find.byType(DkProgressSheet), findsNothing);

    run.progress.add(
      const JobProgress(
        'reading',
        pageIndex: 17,
        pageCount: 40,
        etaSeconds: 20,
      ),
    );
    await tester.pump(const Duration(seconds: 8));
    await settle(tester);
    expect(find.text('Compressing Mietvertrag.pdf'), findsOneWidget);
    expect(find.textContaining('Page 18 of 40'), findsOneWidget);
    expect(find.textContaining('20 s left'), findsOneWidget);

    // A jump to 100 s shows as 30 s.
    run.progress.add(
      const JobProgress(
        'reading',
        pageIndex: 18,
        pageCount: 40,
        etaSeconds: 100,
      ),
    );
    await tester.pump();
    expect(find.textContaining('30 s left'), findsOneWidget);

    run.result.complete(null);
    await settle(tester);
    expect(find.byType(DkProgressSheet), findsNothing);
    expect(find.text('T3'), findsOneWidget);
    expect(run.discarded, isFalse);
  });

  testWidgets('finished out of sight: Home gets it as a continue card '
      '(DK-0247)', (tester) async {
    final router = await pumpT2(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await start(tester);
    // The user goes elsewhere while it runs.
    router.push('/tool/merge');
    await settle(tester);
    run.result.complete(const OneFile('Mietvertrag_small.pdf'));
    await settle(tester);
    final waiting = container.read(backgroundResultProvider);
    expect(waiting?.toolId, 'compress');
    expect(waiting?.files, ['Mietvertrag_small.pdf']);
  });

  testWidgets('finished in view: T3, and no continue card', (tester) async {
    await pumpT2(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await start(tester);
    run.result.complete(const OneFile('Mietvertrag_small.pdf'));
    await settle(tester);
    expect(find.text('T3'), findsOneWidget);
    expect(container.read(backgroundResultProvider), isNull);
  });

  testWidgets('Cancel before 30 s stops at once: "Cancelled", nothing kept '
      '(DK-0376)', (tester) async {
    await pumpT2(tester);
    await start(tester);
    await tester.pump(const Duration(seconds: 11));
    await settle(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(run.cancelled, isTrue);
    expect(run.discarded, isTrue);
    expect(find.byType(DkProgressSheet), findsNothing);
    expect(
      find.text("Cancelled. Your original file wasn't changed."),
      findsOne,
    );
    expect(bar(tester).label, 'Compress 0 pages', reason: 'ready again');
  });

  testWidgets('Cancel after 30 s asks "Stop compressing?" first', (
    tester,
  ) async {
    await pumpT2(tester);
    await start(tester);
    await tester.pump(const Duration(seconds: 31));
    await settle(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Stop compressing?'), findsOneWidget);
    await tester.tap(find.text('Keep going'));
    await settle(tester);
    expect(run.cancelled, isFalse);

    await tester.tap(find.text('Cancel'));
    await settle(tester);
    await tester.tap(find.text('Stop'));
    await settle(tester);
    expect(run.cancelled, isTrue);
  });

  testWidgets('a failure turns the sheet into its error state with the '
      "catalogue's title and action (DK-0377)", (tester) async {
    await pumpT2(tester);
    await start(tester);
    // Fails within 2 s: the sheet opens in its error state anyway.
    run.result.completeError(const DocError(DocErrorKind.damaged));
    await settle(tester);
    expect(find.text("This file can't be opened."), findsOneWidget);
    expect(find.text("Your original file wasn't changed."), findsOneWidget);
    expect(run.discarded, isTrue);

    await tester.tap(find.text('Try Repair'));
    await settle(tester);
    expect(find.text('T2 repair'), findsOneWidget);
  });
}
