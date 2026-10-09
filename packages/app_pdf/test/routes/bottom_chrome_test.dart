import 'package:app_pdf/components/dk_mini_job_bar.dart';
import 'package:app_pdf/components/dk_progress_sheet.dart';
import 'package:app_pdf/components/dk_scan_button.dart';
import 'package:app_pdf/components/dk_toast.dart';
import 'package:app_pdf/providers/job_providers.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'routes_test.dart' show pumpAt;

class _Jobs extends RunningJobs {
  _Jobs(this.jobs);
  final List<RunningJob> jobs;

  @override
  List<RunningJob> build() => jobs;
}

RunningJob job(int id, {VoidCallback? cancel}) => RunningJob(
  id: id,
  toolId: 'compress',
  cancel: cancel ?? () {},
  progress: const JobProgress('reading', pageIndex: 17, pageCount: 40),
);

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(393, 852)
      ..devicePixelRatio = 1;
  });
  tearDown(
    () => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .reset(),
  );

  testWidgets('no jobs: no mini bar', (tester) async {
    await pumpAt(tester, Routes.home);
    expect(find.byType(DkMiniJobBar), findsNothing);
  });

  testWidgets('a running job rides above the tab bar, clear of the raised '
      'Scan button; a toast floats above it (DK-0233)', (tester) async {
    await pumpAt(
      tester,
      Routes.home,
      overrides: [
        runningJobsProvider.overrideWith(() => _Jobs([job(1)])),
      ],
    );
    expect(find.text('Compress PDF · Page 18 of 40'), findsOneWidget);
    final bar = tester.getRect(find.byType(DkMiniJobBar));
    final scan = tester.getRect(find.byType(DkScanButton));
    expect(bar.bottom, lessThanOrEqualTo(scan.top), reason: 'not over Scan');

    final context = tester.element(find.byType(DkMiniJobBar));
    showDkToast(context, 'Saved');
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(SnackBar)).bottom,
      lessThanOrEqualTo(bar.top),
      reason: 'the toast stacks above the mini bar',
    );
  });

  testWidgets('several jobs collapse into "3 jobs running"', (tester) async {
    await pumpAt(
      tester,
      Routes.files,
      overrides: [
        runningJobsProvider.overrideWith(() => _Jobs([job(1), job(2), job(3)])),
      ],
    );
    expect(find.text('3 jobs running'), findsOneWidget);
  });

  testWidgets(
    'tapping the bar opens the progress sheet; Cancel stops the job',
    (tester) async {
      var cancelled = false;
      await pumpAt(
        tester,
        Routes.home,
        overrides: [
          runningJobsProvider.overrideWith(
            () => _Jobs([job(1, cancel: () => cancelled = true)]),
          ),
        ],
      );
      await tester.tap(find.byType(DkMiniJobBar));
      await tester.pumpAndSettle();
      expect(find.byType(DkProgressSheet), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(cancelled, isTrue);
      expect(find.byType(DkProgressSheet), findsNothing);
    },
  );
}
