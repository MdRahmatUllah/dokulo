import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_promo_cards.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/formats.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';
import '../../tools/tool_catalogue.dart';
import '../../tools/tool_definition.dart';
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
