import 'package:app_pdf/components/dk_progress_sheet.dart';
import 'package:app_pdf/providers/job_providers.dart';
import 'package:app_pdf/routes/link_error.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'routes_test.dart' show pumpAt, title;

import 'package:app_pdf/screens/home/home_screen.dart';

class _Jobs extends RunningJobs {
  _Jobs(this.jobs);
  final List<RunningJob> jobs;

  @override
  List<RunningJob> build() => jobs;
}

/// What the platform sends when a link arrives while the app runs.
Future<void> openLink(WidgetTester tester, String link) async {
  final message = const JSONMethodCodec().encodeMethodCall(
    MethodCall('pushRouteInformation', {'location': link, 'state': null}),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    message,
    (_) {},
  );
  await tester.pumpAndSettle();
}

/// The deep links of DK-0236: cold and warm starts, and the links that
/// lead nowhere (each says so, none crashes). Every route's cold start:
/// routes_test.
void main() {
  testWidgets('warm start: a dokulo:// link opens its route over the '
      'running app, and a broken one says so', (tester) async {
    await pumpAt(tester, Routes.files);
    await openLink(tester, 'dokulo://open/tool/compress');
    expect(title(tester), 'T2 compress');
    await openLink(tester, 'dokulo://open/scan?mode=idCard');
    expect(title(tester), 'S1 idCard');
    await openLink(tester, 'dokulo://open/me/models');
    expect(title(tester), 'M2');
    await openLink(tester, 'dokulo://open/tool/teleport');
    expect(find.byType(LinkErrorScreen), findsOneWidget);
  });

  testWidgets('a link to no route shows the link error, with a way Home', (
    tester,
  ) async {
    await pumpAt(tester, '/nowhere/at/all');
    expect(find.text("This link doesn't work any more"), findsOneWidget);
    await tester.tap(find.text('Go to Home'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a link to a tool this version lacks shows the link error', (
    tester,
  ) async {
    await pumpAt(tester, Routes.tool('teleport'));
    expect(find.byType(LinkErrorScreen), findsOneWidget);
  });

  group('a tool link with a file handle', () {
    late DokuloDatabase db;
    setUp(() => db = DokuloDatabase.memory());
    tearDown(() => db.close());

    testWidgets('opens the tool when the file is there', (tester) async {
      final id = await tester.runAsync(
        () => db
            .into(db.files)
            .insert(
              FilesCompanion.insert(
                path: 'a.pdf',
                name: 'a.pdf',
                size: 1,
                created: DateTime(2026),
                modified: DateTime(2026),
              ),
            ),
      );
      expect(Routes.tool('compress', fileId: '$id'), '/tool/compress?file=$id');
      await pumpAt(
        tester,
        Routes.tool('compress', fileId: '$id'),
        database: db,
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(title(tester), 'T2 compress');
    });

    for (final handle in ['999', 'f42']) {
      testWidgets('says the file is gone for an expired or bad handle '
          '($handle)', (tester) async {
        await pumpAt(
          tester,
          Routes.tool('compress', fileId: handle),
          database: db,
        );
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
        expect(find.text("This file isn't in Dokulo any more."), findsOne);
      });
    }
  });

  testWidgets("a job link opens Home with the job's progress", (tester) async {
    final job = RunningJob(
      id: 7,
      toolId: 'compress',
      cancel: () {},
      progress: const JobProgress('reading', pageIndex: 1, pageCount: 4),
    );
    await pumpAt(
      tester,
      Routes.job(7),
      overrides: [
        runningJobsProvider.overrideWith(() => _Jobs([job])),
      ],
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(DkProgressSheet), findsOneWidget);
  });

  testWidgets('a job link after the job ended says so on Home', (tester) async {
    await pumpAt(tester, Routes.job(7));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('This job has already finished.'), findsOneWidget);
  });
}
