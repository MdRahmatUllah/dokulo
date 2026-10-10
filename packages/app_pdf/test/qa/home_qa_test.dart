import 'package:app_pdf/providers/files_providers.dart';
import 'package:app_pdf/providers/job_providers.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart' show JobProgress;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/home_screen_test.dart' show pumpHome, settle;

// Visual QA (DK-0716, DK-0719, DK-0720, DK-0723, DK-0724): the 02-home
// frames first, edit, addtool, job and jobs3, rendered by the real H1 in the
// shell at 393 × 852. The goldens sit next to the frames' screenshots in
// docs/qa/home/; the findings are in docs/qa/home-files.md.

class _Jobs extends RunningJobs {
  _Jobs(this.count);
  final int count;

  @override
  List<RunningJob> build() => [
    for (var i = 0; i < count; i++)
      RunningJob(
        id: i + 1,
        toolId: 'compress',
        cancel: () {},
        progress: JobProgress('compress', pageIndex: 7, pageCount: 12),
      ),
  ];
}

void main() {
  late DokuloDatabase db;
  setUp(() => db = DokuloDatabase.memory());
  tearDown(() => db.close());

  /// The frames' recent files, opened today.
  Future<void> recents(WidgetTester tester) => tester.runAsync(() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final (name, size, pages, at) in [
      ('Mietvertrag Musterstraße 12.pdf', 2400000, 12, 14 * 60 + 32),
      ('Invoice INV-2026-014.pdf', 186000, 2, 9 * 60 + 5),
      ('Personalausweis – scan.pdf', 1100000, 2, 8 * 60),
    ]) {
      final when = today.add(Duration(minutes: at));
      final id = await db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              path: '/x/$name',
              name: name,
              size: size,
              pages: Value(pages),
              created: when,
              modified: when,
            ),
          );
      await db
          .into(db.recents)
          .insert(RecentsCompanion.insert(fileId: Value(id), openedAt: when));
    }
  });

  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    Future<void> shot(WidgetTester tester, String frame) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/qa_home_${frame}_$theme.png'),
    );

    testWidgets('home-first, $theme', (tester) async {
      await pumpHome(tester, db, tokens: tokens);
      await shot(tester, 'first');
    });

    testWidgets('home-edit, $theme', (tester) async {
      await recents(tester);
      await pumpHome(tester, db, tokens: tokens);
      await tester.tap(find.text('Edit'));
      await settle(tester);
      await shot(tester, 'edit');
    });

    testWidgets('home-addtool, $theme', (tester) async {
      await recents(tester);
      // 7 pinned, so the Add tile shows (the 8th hides it, DK-0249).
      await tester.runAsync(
        () => savePinnedTools(db, defaultPinnedTools.take(7).toList()),
      );
      await pumpHome(tester, db, tokens: tokens);
      await tester.tap(find.text('Edit'));
      await settle(tester);
      await tester.tap(find.text('Add tool'));
      await settle(tester);
      await shot(tester, 'addtool');
    });

    for (final (frame, jobs) in [('job', 1), ('jobs3', 3)]) {
      testWidgets('home-$frame, $theme', (tester) async {
        await recents(tester);
        await pumpHome(
          tester,
          db,
          tokens: tokens,
          overrides: [runningJobsProvider.overrideWith(() => _Jobs(jobs))],
        );
        await shot(tester, frame);
      });
    }
  }
}
