import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../components/dk_icon.dart';
import '../../components/dk_promo_cards.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/formats.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';
import '../../tools/tool_catalogue.dart';
import '../../tools/tool_definition.dart';
import '../s1_scanner/scan_session.dart';
import '../t2_tool/tool_options_providers.dart';

/// H1's continue card (UI spec §15.2, region 3): a job that finished while
/// its T2 was out of sight (DK-0247): the tool's icon, "Compressed
/// Mietvertrag.pdf", "1.9 MB (−77 %)", Open → T3, × dismisses. 16 below the
/// privacy line; nothing when there is no such job.
class HomeContinueCard extends ConsumerWidget {
  const HomeContinueCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(backgroundResultProvider);
    if (result == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final tool = ToolCatalogue.of(result.toolId);
    final def = ToolDefinitions.of(result.toolId);
    final file = result.inputs.isNotEmpty
        ? result.inputs.first.name
        : File(result.files.first).uri.pathSegments.last;
    final summary = def.summary?.call(l, result);
    final sub = summary == null
        ? switch (result.files) {
            [final one] when File(one).existsSync() => formatBytes(
              File(one).lengthSync(),
              locale,
            ),
            final many => l.t3_files(many.length),
          }
        : [summary.headline, ?summary.delta].join(' ');
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(t.space.l, t.space.l, t.space.l, 0),
      sliver: SliverToBoxAdapter(
        child: DkContinueCard(
          icon: tool.icon,
          title:
              def.doneTitle?.call(l, file) ??
              l.home_continue_job(tool.name(l), file),
          sub: sub,
          action: l.common_open,
          onAction: () {
            ref.read(lastToolResultProvider.notifier).set(result);
            ref.read(backgroundResultProvider.notifier).set(null);
            context.push(Routes.toolResult(result.toolId));
          },
          onDismiss: () =>
              ref.read(backgroundResultProvider.notifier).set(null),
        ),
      ),
    );
  }
}

/// H1's continue card for an unsaved scan (DK-0246; UI spec §15.2,
/// home-contscan): "Scan of 6 pages not saved", "Started today 14:32",
/// Continue → S2 with the pages. The scan is on disk (`ScanSession`), so it
/// comes back after the app was killed; × hides the card for this visit
/// only, the scan stays until S2 saves or discards it.
class HomeScanCard extends ConsumerStatefulWidget {
  const HomeScanCard({super.key});

  @override
  ConsumerState<HomeScanCard> createState() => _HomeScanCardState();
}

class _HomeScanCardState extends ConsumerState<HomeScanCard> {
  var _hidden = false;

  @override
  void initState() {
    super.initState();
    // After a kill the session is empty until the manifest is read. A store
    // that can't be read just means no card: Home never fails over it.
    ref
        .read(scanSessionProvider.notifier)
        .restore()
        .onError<Exception>((_, _) {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = ref.watch(scanSessionProvider);
    if (pages.isEmpty || _hidden) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(t.space.l, t.space.l, t.space.l, 0),
      sliver: SliverToBoxAdapter(
        child: DkContinueCard(
          icon: DkIcons.scan,
          title: l.home_scan_unsaved(pages.length),
          sub: switch (scanStarted(pages.first)) {
            null => '',
            final at => started(l, at, locale, DateTime.now()),
          },
          action: l.common_continue,
          onAction: () => context.push(Routes.scanReview),
          onDismiss: () => setState(() => _hidden = true),
        ),
      ),
    );
  }
}

/// When the scan began: a page's id starts with its capture time in
/// microseconds (`ScanSession`).
DateTime? scanStarted(ScannedPage first) =>
    switch (RegExp(r'^\d+').stringMatch(first.id)) {
      final us? => DateTime.fromMicrosecondsSinceEpoch(int.parse(us)),
      null => null,
    };

/// "Started today 14:32", "Started yesterday 9:05", "Started 7 Oct 2026".
String started(AppLocalizations l, DateTime at, String locale, DateTime now) {
  final days = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime.utc(at.year, at.month, at.day)).inDays;
  final time = DateFormat.Hm(locale).format(at);
  return switch (days) {
    0 => l.home_scan_started_today(time),
    1 => l.home_scan_started_yesterday(time),
    _ => l.home_scan_started_on(formatDate(at, locale)),
  };
}
