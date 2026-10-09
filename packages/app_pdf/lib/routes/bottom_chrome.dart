import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/dk_mini_job_bar.dart';
import '../components/dk_progress_sheet.dart';
import '../components/dk_sheet.dart';
import '../components/dk_toast.dart';
import '../l10n/app_localizations.dart';
import '../l10n/formats.dart';
import '../providers/job_providers.dart';
import '../theme/dk_tokens.dart';
import '../tools/tool_catalogue.dart';

/// A screen's bottom chrome with the running jobs above it (UI spec §11.6,
/// §20.2; DK-0233): while jobs run, DkMiniJobBar sits 8 above [child] (the
/// tab bar, an action bar, or nothing), "3 jobs running" when several. Put
/// it in the Scaffold's `bottomNavigationBar`: toasts then float above the
/// mini bar (showDkToast), and the mini bar never covers the screen's own
/// buttons.
///
/// [clearance] keeps it clear of something that rises above [child]: the
/// raised Scan button over the tab bar.
class DkBottomChrome extends ConsumerWidget {
  const DkBottomChrome({super.key, this.child, this.clearance = 0});

  final Widget? child;
  final double clearance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(runningJobsProvider);
    if (jobs.isEmpty) return child ?? const SizedBox.shrink();
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final job = jobs.last;
    final tool = ToolCatalogue.of(job.toolId);
    final p = job.progress;
    final label = [
      tool.name(l10n),
      if (p?.pageIndex != null && p?.pageCount != null)
        l10n.progress_page(p!.pageIndex! + 1, p.pageCount!),
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
