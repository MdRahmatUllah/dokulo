import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/dk_confirm_dialog.dart';
import '../components/dk_icon.dart';
import '../components/dk_mini_job_bar.dart';
import '../components/dk_progress_sheet.dart';
import '../components/dk_sheet.dart';
import '../components/dk_toast.dart';
import '../l10n/app_localizations.dart';
import '../l10n/formats.dart';
import '../providers/job_providers.dart';
import '../providers/notification_permission.dart';
import '../providers/prefs_providers.dart';
import '../theme/dk_tokens.dart';
import '../tools/tool_catalogue.dart';
import '../tools/tool_definition.dart';

/// A screen's bottom chrome with the running jobs above it (UI spec §11.6,
/// §20.2; DK-0233): while jobs run, DkMiniJobBar sits 8 above [child] (the
/// tab bar, an action bar, or nothing), "3 jobs running" when several. Put
/// it in the Scaffold's `bottomNavigationBar`: toasts then float above the
/// mini bar (showDkToast), and the mini bar never covers the screen's own
/// buttons.
///
/// [clearance] keeps it clear of something that rises above [child]: the
/// raised Scan button over the tab bar.
class DkBottomChrome extends ConsumerStatefulWidget {
  const DkBottomChrome({super.key, this.child, this.clearance = 0});

  final Widget? child;
  final double clearance;

  @override
  ConsumerState<DkBottomChrome> createState() => _DkBottomChromeState();
}

/// How long a job runs in the background before the app offers notices.
const notificationPromptAfter = Duration(seconds: 30);

/// The prefs key: the notice pre-prompt was shown (at most once, DK-0378).
const notificationsAskedKey = 'notifications.asked';

class _DkBottomChromeState extends ConsumerState<DkBottomChrome> {
  Timer? _prompt;

  @override
  void dispose() {
    _prompt?.cancel();
    super.dispose();
  }

  /// DK-0378: a job runs in the background (the mini bar shows) 30 s after
  /// it started: "Get a notice when long jobs finish?", once ever; Continue
  /// asks the system. Only the screen on top asks.
  void _schedulePrompt(List<RunningJob> jobs) {
    if (_prompt != null) return;
    final started = jobs.first.started;
    if (started == null) return;
    final wait = notificationPromptAfter - DateTime.now().difference(started);
    _prompt = Timer(wait.isNegative ? Duration.zero : wait, () async {
      _prompt = null;
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
      if (ref.read(runningJobsProvider).isEmpty) return;
      final prefs = await ref.read(prefsProvider.future);
      if (prefs[notificationsAskedKey] == true || !mounted) return;
      final permission = ref.read(notificationPermissionProvider);
      if (await permission.status() != NotificationAccess.notAsked) return;
      if (!mounted) return;
      await ref.read(prefsProvider.notifier).set(notificationsAskedKey, true);
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      final yes = await showDkConfirm(
        context,
        title: l.notif_prompt_title,
        body: l.notif_prompt_body,
        action: l.common_continue,
        cancel: l.common_not_now,
        icon: DkIcons.notifications,
      );
      if (yes) await permission.request();
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final clearance = widget.clearance;
    final jobs = ref.watch(runningJobsProvider);
    if (jobs.isEmpty) {
      _prompt?.cancel();
      _prompt = null;
      return child ?? const SizedBox.shrink();
    }
    _schedulePrompt(jobs);
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final job = jobs.last;
    final tool = ToolCatalogue.of(job.toolId);
    final p = job.progress;
    // "Compressing · 18 of 40" (tool-shell-minibar): the tool's busy verb
    // without its ellipsis, or its name.
    final busy = ToolDefinitions.of(job.toolId).busyLabel?.call(l10n);
    final label = [
      busy?.replaceAll('…', '').trim() ?? tool.name(l10n),
      if (p?.pageIndex != null && p?.pageCount != null)
        l10n.progress_of(p!.pageIndex! + 1, p.pageCount!),
    ].join(' · ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: t.space.s + clearance),
          child: DkMiniJobBar(
            icon: tool.icon,
            label: label,
            progress: p?.fraction ?? 0,
            jobs: jobs.length,
            onTap: () => showJobProgress(context, job.id),
          ),
        ),
        ?child,
      ],
    );
  }
}

/// The progress sheet of the job with row [id], live until the job ends
/// (then it closes). Cancel stops the job; Keep working closes the sheet.
/// A job that isn't running (a stale link) gets a toast instead.
// ponytail: several jobs open the newest one's sheet; a job list when
// someone runs three at once and asks for it.
void showJobProgress(BuildContext context, int id) {
  final container = ProviderScope.containerOf(context, listen: false);
  if (!container.read(runningJobsProvider).any((j) => j.id == id)) {
    showDkToast(context, AppLocalizations.of(context).link_job_finished);
    return;
  }
  showDkSheet<void>(
    context,
    body: Consumer(
      builder: (context, ref, _) {
        final job = ref
            .watch(runningJobsProvider)
            .where((j) => j.id == id)
            .firstOrNull;
        if (job == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
          return const SizedBox.shrink();
        }
        final tool = ToolCatalogue.of(job.toolId);
        final p = job.progress;
        final l10n = AppLocalizations.of(context);
        return DkProgressSheet(
          toolIcon: tool.icon,
          title: tool.name(l10n),
          progress: p?.fraction ?? 0,
          page: p?.pageIndex == null ? null : p!.pageIndex! + 1,
          pageCount: p?.pageCount,
          timeLeft: p?.etaSeconds == null
              ? null
              : formatSeconds(p!.etaSeconds!),
          onCancel: () {
            job.cancel();
            Navigator.of(context).maybePop();
          },
          onKeepWorking: () => Navigator.of(context).maybePop(),
        );
      },
    ),
  );
}
