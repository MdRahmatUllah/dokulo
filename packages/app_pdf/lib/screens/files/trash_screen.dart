import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_action_sheet.dart';
import '../../components/dk_banner.dart';
import '../../components/dk_file_card.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_skeleton.dart';
import '../../components/dk_text_action.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/formats.dart';
import '../../patterns/dk_confirmations.dart';
import '../../patterns/dk_empty_states.dart';
import '../../providers/database_providers.dart';
import '../../providers/file_providers.dart';
import '../../providers/files_providers.dart';
import '../../theme/dk_tokens.dart';

/// R1 · Recently deleted (DK-0278; UI spec §16.5): the small top bar with
/// Empty (danger text); the info banner with the retention; a row per file,
/// "{size} · {n} days left", its button restores; a tap opens Restore ·
/// Delete for good. Empty: ILL-08. The launch purge (DK-0021) removes the
/// expired ones.
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final days = ref.watch(trashRetentionDaysProvider);
    final trashed = ref.watch(trashedFilesProvider);
    final rows = trashed.value ?? const [];
    return Scaffold(
      backgroundColor: t.color.background,
      appBar: DkTopBar(
        title: l.files_recently_deleted,
        trailing: DkTextAction(
          label: l.trash_empty,
          danger: true,
          onTap: rows.isEmpty ? null : () => _empty(context, ref, rows),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          if (!trashed.hasValue)
            SliverPadding(
              padding: EdgeInsets.only(top: t.space.l),
              sliver: SliverToBoxAdapter(child: DkSkeleton.fileRows()),
            )
          else if (rows.isEmpty)
            SliverFillRemaining(
              hasScrollBody: true, // DkEmptyState centres and scrolls itself
              child: DkEmptyStates.trash(context),
            )
          else ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                t.space.l,
                t.space.s,
                t.space.l,
                t.space.s,
              ),
              sliver: SliverToBoxAdapter(
                child: DkBanner(text: l.trash_banner(days)),
              ),
            ),
            SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (_, i) =>
                  _TrashRow(rows[i].file, rows[i].deletedAt, days),
            ),
            SliverToBoxAdapter(child: SizedBox(height: t.space.xl)),
          ],
        ],
      ),
    );
  }

  Future<void> _empty(
    BuildContext context,
    WidgetRef ref,
    List<({FileEntry file, DateTime deletedAt})> rows,
  ) async {
    if (!await confirmDk(
      context,
      DkConfirmation.emptyTrash,
      count: rows.length,
    )) {
      return;
    }
    final db = ref.read(appDatabaseProvider);
    final store = await ref.read(fileStoreProvider.future);
    for (final r in rows) {
      await store.deleteForever(db, r.file.id);
    }
  }
}

/// Days until the launch purge takes a file deleted at [deletedAt].
@visibleForTesting
int daysLeft(DateTime deletedAt, int retention, {DateTime? now}) {
  final left = deletedAt
      .add(Duration(days: retention))
      .difference(now ?? DateTime.now());
  return (left.inHours / 24).ceil().clamp(0, retention);
}

class _TrashRow extends ConsumerWidget {
  const _TrashRow(this.file, this.deletedAt, this.retention);

  final FileEntry file;
  final DateTime deletedAt;
  final int retention;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final meta = [
      formatBytes(file.size, locale),
      l.meta_days_left(daysLeft(deletedAt, retention)),
    ].join(' · ');
    final thumbnail = switch (ref.watch(fileThumbnailProvider(file.path, 96))) {
      AsyncData(:final value) => RawImage(image: value, fit: BoxFit.cover),
      AsyncError() => ColoredBox(color: context.tokens.color.pageWhite),
      _ => null,
    };
    return DkFileCard(
      name: file.name,
      meta: meta,
      encrypted: file.encrypted,
      thumbnail: thumbnail,
      moreIcon: DkIcons.restoreFromTrash,
      moreLabel: l.common_restore,
      onMore: () => _restore(ref),
      onTap: () => showDkActionSheet(
        context,
        header: DkActionSheetHeader(
          thumbnail: thumbnail ?? const SizedBox.shrink(),
          name: file.name,
          meta: meta,
        ),
        groups: [
          [
            DkAction(
              icon: DkIcons.restoreFromTrash,
              label: l.common_restore,
              onTap: () => _restore(ref),
            ),
            DkAction(
              icon: DkIcons.deleteForever,
              label: l.common_delete_forever,
              destructive: true,
              onTap: () => _deleteForever(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _restore(WidgetRef ref) async {
    final store = await ref.read(fileStoreProvider.future);
    await store.restoreFromTrash(ref.read(appDatabaseProvider), file.id);
  }

  Future<void> _deleteForever(BuildContext context, WidgetRef ref) async {
    if (!await confirmDk(context, DkConfirmation.deleteForever)) return;
    final store = await ref.read(fileStoreProvider.future);
    await store.deleteForever(ref.read(appDatabaseProvider), file.id);
  }
}
