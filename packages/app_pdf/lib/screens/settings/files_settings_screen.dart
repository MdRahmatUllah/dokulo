import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../components/dk_action_sheet.dart';
import '../../components/dk_button.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_menu.dart';
import '../../components/dk_settings_row.dart';
import '../../components/dk_toast.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/formats.dart';
import '../../providers/file_providers.dart';
import '../../providers/files_providers.dart';
import '../../providers/job_providers.dart';
import '../../providers/prefs_providers.dart';
import '../../theme/dk_tokens.dart';

/// What the app takes on the phone (DK-0281): the user's files, the AI
/// models, and what can be cleared (thumbnails, temp).
typedef StorageUse = ({int files, int models, int cache});

/// Bytes under [dir], 0 if it isn't there.
Future<int> dirSize(Directory dir) async {
  if (!await dir.exists()) return 0;
  var total = 0;
  await for (final e in dir.list(recursive: true, followLinks: false)) {
    if (e is File) total += await e.length();
  }
  return total;
}

/// The three sizes for Files & storage.
final storageUseProvider = FutureProvider.autoDispose<StorageUse>((ref) async {
  final files = await ref.watch(fileStoreProvider.future);
  final thumbs = await ref.watch(thumbnailCacheProvider.future);
  // ponytail: ai_core's model manager will own this folder; until then
  // the models are wherever <app support>/models says.
  final models = await ref.watch(modelsDirectoryProvider.future);
  return (
    files: await dirSize(files.userFolder),
    models: await dirSize(models),
    cache: await dirSize(thumbs.directory) + await dirSize(files.temp),
  );
});

/// Clear cache (DK-0281: "thumbnails/temp files only"): every thumbnail,
/// and the temp files older than a day while no job runs, so an unsaved
/// result waiting in temp (or a job writing there) keeps its file. The
/// inbox (files shared in, not yet imported) stays.
// ponytail: the 24 h guard; per-file ownership if a result ever waits longer.
Future<void> clearCache(
  Directory thumbnails,
  Directory temp, {
  required bool jobsRunning,
  required DateTime now,
}) async {
  if (await thumbnails.exists()) await thumbnails.delete(recursive: true);
  if (jobsRunning || !await temp.exists()) return;
  await for (final e in temp.list(followLinks: false)) {
    final stat = await e.stat();
    if (now.difference(stat.modified) > const Duration(days: 1)) {
      await e.delete(recursive: true);
    }
  }
}

/// Where on-demand models are kept.
final modelsDirectoryProvider = FutureProvider<Directory>(
  (ref) async => Directory(
    '${(await getApplicationSupportDirectory()).path}'
    '${Platform.pathSeparator}models',
  ),
);

/// M3 · Files & storage (DK-0572; UI spec §23.3): Default save folder ·
/// Keep deleted files (7 / 30 days; 30) · the storage bar (Files, AI
/// models, Cache) with Clear cache · Export all files.
class FilesSettingsScreen extends ConsumerWidget {
  const FilesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final days = ref.watch(trashRetentionDaysProvider);
    final use = ref.watch(storageUseProvider).value;
    return Scaffold(
      backgroundColor: t.color.background,
      appBar: DkTopBar(title: l.me_files_storage),
      body: ListView(
        padding: EdgeInsets.all(t.space.l),
        children: [
          DkSettingsGroup(
            children: [
              // ponytail: one folder for now; choosing another comes when
              // users ask (it moves the index's root).
              DkSettingsRow(
                title: l.files_settings_save_folder,
                value: 'Dokulo', // l10n-ignore: the folder's name on disk
              ),
              Builder(
                builder: (anchor) => DkSettingsRow(
                  title: l.files_settings_keep,
                  value: l.files_settings_days(days),
                  onTap: () => showDkMenu(
                    anchor,
                    groups: [
                      [
                        for (final d in const [7, 30])
                          DkAction(
                            label: l.files_settings_days(d),
                            checked: d == days,
                            onTap: () => ref
                                .read(prefsProvider.notifier)
                                .set('trash.days', d),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: t.space.l),
          DkSettingsGroup(
            title: l.storage_title,
            children: [
              Padding(
                padding: EdgeInsets.all(t.space.l),
                child: _StorageBar(use: use, locale: locale),
              ),
            ],
          ),
          SizedBox(height: t.space.l),
          DkSettingsGroup(
            children: [
              // ponytail: needs share_plus (agent-2's DK-1077); enabled with it.
              DkSettingsRow(
                icon: DkIcons.share(context),
                title: l.files_settings_export,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StorageBar extends ConsumerWidget {
  const _StorageBar({required this.use, required this.locale});

  final StorageUse? use;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final u = use;
    final parts = [
      (l.shell_tab_files, u?.files ?? 0, c.primary),
      (l.me_ai_models, u?.models ?? 0, c.success),
      (l.storage_cache, u?.cache ?? 0, c.outlineStrong),
    ];
    final total = parts.fold<int>(0, (s, p) => s + p.$2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: t.space.m,
      children: [
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(t.radius.xs),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  for (final (_, bytes, colour) in parts)
                    if (bytes > 0)
                      Expanded(
                        flex: (bytes * 1000 ~/ (total == 0 ? 1 : total)).clamp(
                          1,
                          1000,
                        ),
                        child: ColoredBox(color: colour),
                      ),
                  if (total == 0)
                    Expanded(child: ColoredBox(color: c.surfaceSunken)),
                ],
              ),
            ),
          ),
        ),
        for (final (label, bytes, colour) in parts)
          MergeSemantics(
            child: Row(
              spacing: t.space.s,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colour,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    label,
                    style: t.text.bodyM.copyWith(color: c.textPrimary),
                  ),
                ),
                Text(
                  u == null ? '…' : formatBytes(bytes, locale),
                  style: t.text.bodyM.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: DkButton(
            label: l.storage_clear,
            variant: DkButtonVariant.tertiary,
            size: DkButtonSize.compact,
            onPressed: () async {
              final thumbs = await ref.read(thumbnailCacheProvider.future);
              final files = await ref.read(fileStoreProvider.future);
              await clearCache(
                thumbs.directory,
                files.temp,
                jobsRunning: ref.read(runningJobsProvider).isNotEmpty,
                now: DateTime.now(),
              );
              ref.invalidate(storageUseProvider);
              if (context.mounted) showDkToast(context, l.storage_cleared);
            },
          ),
        ),
      ],
    );
  }
}
