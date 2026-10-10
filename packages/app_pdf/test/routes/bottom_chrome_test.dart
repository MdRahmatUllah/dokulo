import 'package:app_pdf/components/dk_mini_job_bar.dart';
import 'package:app_pdf/components/dk_progress_sheet.dart';
import 'package:app_pdf/components/dk_scan_button.dart';
import 'package:app_pdf/components/dk_toast.dart';
import 'package:app_pdf/providers/job_providers.dart';
import 'package:app_pdf/providers/notification_permission.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/routes/bottom_chrome.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class _FakeNotifications implements NotificationPermission {
  _FakeNotifications(this.access);
  NotificationAccess access;
  var requests = 0;

  @override
  Future<NotificationAccess> status() async => access;

  @override
  Future<NotificationAccess> request() async {
    requests++;
    return access = NotificationAccess.granted;
  }
}

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
    expect(find.text('Compress PDF · 18 of 40'), findsOneWidget);
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

  group('the notice pre-prompt (DK-0378)', () {
    RunningJob longJob() => RunningJob(
      id: 1,
      toolId: 'compress',
      cancel: () {},
      started: DateTime.now().subtract(notificationPromptAfter),
    );

    Future<_FakeNotifications> pumpLong(
      WidgetTester tester, {
      NotificationAccess access = NotificationAccess.notAsked,
      DkTokens? tokens,
    }) async {
      final fake = _FakeNotifications(access);
      await pumpAt(
        tester,
        Routes.tools,
        tokens: tokens,
        overrides: [
          runningJobsProvider.overrideWith(() => _Jobs([longJob()])),
          notificationPermissionProvider.overrideWithValue(fake),
        ],
      );
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpAndSettle();
      return fake;
    }

    Object? asked(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(DkBottomChrome).first),
    ).read(prefsProvider).value?[notificationsAskedKey];

    testWidgets('30 s into a job in the background: asks once; Continue '
        'asks the system', (tester) async {
      final fake = await pumpLong(tester);
      expect(find.text('Get a notice when long jobs finish?'), findsOneWidget);
      expect(asked(tester), isTrue, reason: 'never again');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(fake.requests, 1);
    });

    testWidgets('Not now: no system prompt', (tester) async {
      final fake = await pumpLong(tester);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(fake.requests, 0);
      expect(find.text('Get a notice when long jobs finish?'), findsNothing);
    });

    // DK-0862: tool-shell-notifprompt, beside the frame in
    // docs/qa/tool-shell/.
    for (final (theme, tokens) in [
      ('light', DkTokens.light),
      ('dark', DkTokens.dark),
    ]) {
      testWidgets('golden: tool_shell_notifprompt_$theme', (tester) async {
        await pumpLong(tester, tokens: tokens);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../qa/goldens/tool_shell_notifprompt_$theme.png'),
        );
      });
    }

    testWidgets('already granted or denied: no prompt', (tester) async {
      await pumpLong(tester, access: NotificationAccess.denied);
      expect(find.text('Get a notice when long jobs finish?'), findsNothing);
    });
  });
}
