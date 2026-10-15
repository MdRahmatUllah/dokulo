import 'package:app_pdf/components/dk_scan_button.dart';
import 'package:app_pdf/providers/files_providers.dart';
import 'package:app_pdf/providers/job_providers.dart';
import 'package:app_pdf/screens/me/me_screen.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_providers.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/tools/tool_definition.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart' show JobProgress, OneFile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/home_screen_test.dart' show pumpHome, settle;

// Visual QA (DK-0715, DK-0716, DK-0718, DK-0719, DK-0720, DK-0721, DK-0723,
// DK-0724, DK-0725, DK-0726): the 02-home frames default, first, contjob,
// edit, addtool, procard, job, jobs3, tilemenu and scanmenu, rendered by the
// real H1 in the shell at 393 × 852. The goldens sit next to the frames' screenshots in
// docs/qa/home/; the findings are in docs/qa/home.md.

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

  /// The frames' recent files: three opened today, or with [six] the
  /// default frame's six (today, yesterday and earlier).
  Future<void> recents(WidgetTester tester, {bool six = false}) =>
      tester.runAsync(() async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        for (final (name, size, pages, at) in [
          if (!six) ...[
            (
              'Mietvertrag Musterstraße 12.pdf',
              2400000,
              12,
              today.add(const Duration(hours: 14, minutes: 32)),
            ),
            (
              'Invoice INV-2026-014.pdf',
              186000,
              2,
              today.add(const Duration(hours: 9, minutes: 5)),
            ),
            (
              'Personalausweis – scan.pdf',
              1100000,
              2,
              today.add(const Duration(hours: 8)),
            ),
          ] else ...[
            (
              'Mietvertrag Musterstraße 12.pdf',
              2400000,
              12,
              today.add(const Duration(hours: 14, minutes: 32)),
            ),
            (
              'Invoice INV-2026-014.pdf',
              186000,
              2,
              today.add(const Duration(hours: 9, minutes: 5)),
            ),
            (
              'Personalausweis – scan.pdf',
              1100000,
              2,
              yesterday.add(const Duration(hours: 18, minutes: 20)),
            ),
            (
              'Finanzamt München – Bescheid 2025.pdf',
              640000,
              4,
              yesterday.add(const Duration(hours: 11, minutes: 47)),
            ),
            ('Whiteboard notes.pdf', 3200000, 1, DateTime(now.year, 10, 5, 16)),
            (
              'Scan 2026-09-30 08.12.pdf',
              1200000,
              3,
              DateTime(now.year, 9, 30, 8),
            ),
          ],
        ]) {
          final id = await db
              .into(db.files)
              .insert(
                FilesCompanion.insert(
                  path: '/x/$name',
                  name: name,
                  size: size,
                  pages: Value(pages),
                  created: at,
                  modified: at,
                ),
              );
          await db
              .into(db.recents)
              .insert(RecentsCompanion.insert(fileId: Value(id), openedAt: at));
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

    testWidgets('home-default, $theme', (tester) async {
      await recents(tester, six: true);
      // Seen once and dismissed today: the Pro card stays away here.
      await pumpHome(
        tester,
        db,
        tokens: tokens,
        overrides: [isProProvider.overrideWithValue(true)],
      );
      await shot(tester, 'default');
    });

    testWidgets('home-contjob, $theme', (tester) async {
      await recents(tester);
      await pumpHome(tester, db, tokens: tokens);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container
          .read(backgroundResultProvider.notifier)
          .set(
            ToolResult(
              toolId: 'compress',
              inputs: [
                FileEntry(
                  id: 99,
                  path: '/x/Mietvertrag.pdf',
                  name: 'Mietvertrag.pdf',
                  size: 8400000,
                  pages: 12,
                  created: DateTime(2026),
                  modified: DateTime(2026),
                  hasText: false,
                  encrypted: false,
                ),
              ],
              output: const OneFile('/x/Mietvertrag_small.pdf'),
              took: const Duration(seconds: 40),
            ),
          );
      await settle(tester);
      await shot(tester, 'contjob');
    });

    testWidgets('home-procard (scrolled), $theme', (tester) async {
      await recents(tester, six: true);
      await pumpHome(tester, db, tokens: tokens);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await settle(tester);
      await shot(tester, 'procard');
    });

    testWidgets('home-tilemenu, $theme', (tester) async {
      await recents(tester);
      await pumpHome(tester, db, tokens: tokens);
      await tester.longPress(find.text('Merge PDF'));
      await settle(tester);
      await shot(tester, 'tilemenu');
    });

    testWidgets('home-scanmenu, $theme', (tester) async {
      await recents(tester);
      await pumpHome(tester, db, tokens: tokens);
      await tester.longPress(find.byType(DkScanButton));
      await settle(tester);
      await shot(tester, 'scanmenu');
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
