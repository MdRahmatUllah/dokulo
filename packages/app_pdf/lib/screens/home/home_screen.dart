import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_button.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_privacy_line.dart';
import '../../components/dk_promo_cards.dart';
import '../../components/dk_refresh.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../patterns/dk_empty_states.dart';
import '../../patterns/dk_open_file.dart';
import '../../providers/database_providers.dart';
import '../../providers/file_providers.dart';
import '../../providers/files_providers.dart';
import '../../providers/prefs_providers.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';
import '../files/files_screen.dart';
import '../me/me_screen.dart';
import 'continue_card.dart';
import 'pinned_tools.dart';

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
            const HomeContinueCard(),
            const PinnedToolsSection(),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(t.space.l, t.space.l, t.space.l, 0),
              sliver: SliverToBoxAdapter(
                child: DkButton(
                  label: l.home_open_file,
                  icon: DkIcons.folderOpen,
                  variant: DkButtonVariant.secondary,
                  expand: true,
                  onPressed: () => openFileFromDevice(context, ref),
                ),
              ),
            ),
            switch (recent) {
              AsyncData(:final value) when value.isEmpty => SliverPadding(
                padding: EdgeInsets.only(top: t.space.xl),
                sliver: SliverToBoxAdapter(
                  child: DkEmptyStates.homeRecents(
                    context,
                    onScan: () => context.push(Routes.scan),
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
                  ..._recentWithProCard(context, ref, value),
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
/// The recent rows, with the Pro card after the 5th (UI spec §15.2 row 9,
/// DK-0251) when [showProCard] says so.
List<Widget> _recentWithProCard(
  BuildContext context,
  WidgetRef ref,
  List<FileEntry> recent,
) {
  final t = context.tokens;
  final prefs = ref.watch(prefsProvider).value ?? const {};
  final dismissals = prefs[proCardDismissals] as int? ?? 0;
  final show = showProCard(
    pro: ref.watch(isProProvider),
    recents: recent.length,
    dismissals: dismissals,
    dismissedAt: DateTime.tryParse(prefs[proCardDismissedAt] as String? ?? ''),
    now: DateTime.now(),
  );
  Widget row(FileEntry f) => FileEntryCard(f, longPressActions: true);
  if (!show) {
    return [
      SliverList.builder(
        itemCount: recent.length,
        itemBuilder: (_, i) => row(recent[i]),
      ),
    ];
  }
  final store = ref.read(prefsProvider.notifier);
  return [
    SliverList.builder(itemCount: 5, itemBuilder: (_, i) => row(recent[i])),
    SliverPadding(
      padding: EdgeInsets.fromLTRB(t.space.l, t.space.s, t.space.l, t.space.s),
      sliver: SliverToBoxAdapter(
        child: DkProCard(
          // ponytail: X3, the paywall sheet, comes with DK-0579 (as on Me).
          onOpen: () {},
          onDismiss: () async {
            await store.set(proCardDismissals, dismissals + 1);
            await store.set(
              proCardDismissedAt,
              DateTime.now().toIso8601String(),
            );
          },
        ),
      ),
    ),
    SliverList.builder(
      itemCount: recent.length - 5,
      itemBuilder: (_, i) => row(recent[i + 5]),
    ),
  ];
}

/// Prefs keys of the Pro card's dismissals.
const proCardDismissals = 'home.proCard.dismissals';
const proCardDismissedAt = 'home.proCard.dismissedAt';

/// H1's Pro card (DK-0251): free users with at least 5 recent files; a
/// dismissal hides it for 30 days (at most once a month), the second one
/// for good.
bool showProCard({
  required bool pro,
  required int recents,
  required int dismissals,
  required DateTime? dismissedAt,
  required DateTime now,
}) =>
    !pro &&
    recents >= 5 &&
    dismissals < 2 &&
    (dismissedAt == null ||
        now.difference(dismissedAt) >= const Duration(days: 30));

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
