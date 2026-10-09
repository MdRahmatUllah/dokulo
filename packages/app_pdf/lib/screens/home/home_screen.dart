import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_button.dart';
import '../../components/dk_empty_state.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_illustration.dart';
import '../../components/dk_privacy_line.dart';
import '../../components/dk_refresh.dart';
import '../../components/dk_tool_tile.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/database_providers.dart';
import '../../providers/file_providers.dart';
import '../../providers/files_providers.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';
import '../files/files_screen.dart';

/// H1 · Home (DK-0242; UI spec §15.1): the large top bar "Dokulo" with
/// search and settings; the privacy line; "Your tools", the pinned tools
/// 4 × 2; "Open a file"; "Recent", up to 20 files. The first launch shows
/// the empty state instead of Recent. Pull to refresh re-scans the folder.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final pinned = ref.watch(pinnedToolsProvider).value ?? defaultPinnedTools;
    final recent = ref.watch(recentFilesProvider);

    return Scaffold(
      backgroundColor: t.color.background,
      body: DkRefresh(
        onRefresh: () async {
          final store = await ref.read(fileStoreProvider.future);
          await store.reconcile(ref.read(appDatabaseProvider));
        },
        child: CustomScrollView(
          slivers: [
            DkLargeTopBar(
              title: 'Dokulo', // l10n-ignore: the brand name, in every language
              actions: [
                DkTopBarAction(
                  icon: DkIcons.search,
                  tooltip: l.home_search,
                  onPressed: () => context.go(Routes.filesSearch),
                ),
                DkTopBarAction(
                  icon: DkIcons.settings,
                  tooltip: l.home_settings,
                  // The settings pages are listed in Me (§23.1, row 4).
                  onPressed: () => context.go(Routes.me),
                ),
              ],
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(t.space.l, t.space.xs, t.space.l, 0),
              sliver: const SliverToBoxAdapter(
                child: DkPrivacyLine(where: DkPrivacyContext.home),
              ),
            ),
            _Header(l.home_your_tools),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: t.space.l),
              sliver: SliverGrid.count(
                crossAxisCount: 4,
                mainAxisSpacing: t.space.m,
                crossAxisSpacing: t.space.m,
                childAspectRatio: 0.78,
                children: [
                  for (final id in pinned.take(8))
                    DkToolTile(
                      toolId: id,
                      onTap: () => context.push(Routes.tool(id)),
                    ),
                ],
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(t.space.l, t.space.l, t.space.l, 0),
              sliver: SliverToBoxAdapter(
                child: DkButton(
                  label: l.home_open_file,
                  icon: DkIcons.folderOpen,
                  variant: DkButtonVariant.secondary,
                  expand: true,
                  // ponytail: Files until the system picker lands (DK-0241)
                  onPressed: () => context.go(Routes.files),
                ),
              ),
            ),
            switch (recent) {
              AsyncData(:final value) when value.isEmpty => SliverPadding(
                padding: EdgeInsets.only(top: t.space.xl),
                sliver: SliverToBoxAdapter(
                  child: DkEmptyState(
                    illustration: DkIllustrations.homeEmpty,
                    title: l.home_empty_title,
                    body: l.home_empty_body,
                    action: l.files_empty_scan,
                    onAction: () => context.push(Routes.scan),
                  ),
                ),
              ),
              AsyncData(:final value) => SliverMainAxisGroup(
                slivers: [
                  _Header(
                    l.home_recent,
                    action: l.home_see_all,
                    onAction: () => context.go(Routes.files),
                  ),
                  SliverList.builder(
                    itemCount: value.length,
                    itemBuilder: (_, i) => FileEntryCard(value[i]),
                  ),
                ],
              ),
              _ => const SliverToBoxAdapter(child: SizedBox.shrink()),
            },
            SliverToBoxAdapter(child: SizedBox(height: t.space.xl)),
          ],
        ),
      ),
    );
  }
}

/// A section header: `titleS` on the left, an optional compact tertiary
/// button on the right; 24 above.
class _Header extends StatelessWidget {
  const _Header(this.text, {this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(t.space.l, t.space.xl, t.space.s, t.space.s),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  text,
                  style: t.text.titleS.copyWith(color: t.color.textPrimary),
                ),
              ),
            ),
            if (action != null)
              DkButton(
                label: action!,
                variant: DkButtonVariant.tertiary,
                size: DkButtonSize.compact,
                onPressed: onAction,
              ),
          ],
        ),
      ),
    );
  }
}
