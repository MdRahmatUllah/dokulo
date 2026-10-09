import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_action_sheet.dart';
import '../../components/dk_file_card.dart';
import '../../components/dk_folder_card.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_menu.dart';
import '../../components/dk_refresh.dart';
import '../../components/dk_settings_row.dart';
import '../../components/dk_skeleton.dart';
import '../../components/dk_text_field.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/formats.dart';
import '../../patterns/dk_empty_states.dart';
import '../../patterns/dk_open_file.dart';
import '../../patterns/dk_text_dialog.dart';
import '../../providers/database_providers.dart';
import '../../providers/file_providers.dart';
import '../../providers/files_providers.dart';
import '../../providers/prefs_providers.dart';
import '../../routes/routes.dart';
import '../../theme/dk_folder_tags.dart';
import '../../theme/dk_tokens.dart';

/// F1 · Files, the root (DK-0260; UI spec §16.1): the large top bar with the
/// view toggle, sort and New folder; the search field; the Locked folder and
/// Recently deleted rows; the folders, then the files, as a list or a
/// 2-column grid. Pull to refresh re-scans the user folder. The view and
/// the sort persist ([Prefs]).
class FilesScreen extends ConsumerWidget {
  const FilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final view = ref.watch(filesViewProvider);
    final folders = ref.watch(foldersProvider(null));
    final files = ref.watch(filesInProvider(null));
    final trash = ref.watch(trashCountProvider).value ?? 0;
    final prefs = ref.read(prefsProvider.notifier);

    final loading = !folders.hasValue || !files.hasValue;
    final empty = !loading && folders.value!.isEmpty && files.value!.isEmpty;

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
              title: l.shell_tab_files,
              actions: [
                DkTopBarAction(
                  icon: view.grid ? DkIcons.listView : DkIcons.gridView,
                  tooltip: view.grid ? l.files_list_view : l.files_grid_view,
                  onPressed: () => prefs.set('files.grid', !view.grid),
                ),
                DkTopBarAction.menu(
                  icon: DkIcons.sort,
                  tooltip: l.files_sort,
                  onMenu: (anchor) => _sortMenu(anchor, l, view, prefs),
                ),
                DkTopBarAction(
                  icon: DkIcons.newFolder,
                  tooltip: l.files_new_folder,
                  onPressed: () => newFolder(context, ref),
                ),
              ],
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(t.space.l, 0, t.space.l, t.space.s),
              sliver: SliverToBoxAdapter(
                child: DkSearchField(
                  hint: l.files_search_hint,
                  // Home's search action opens F1 with the field focused.
                  autofocus:
                      GoRouterState.of(context).uri.queryParameters['search'] ==
                      '1',
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(t.space.l, t.space.s, t.space.l, 0),
              sliver: SliverToBoxAdapter(
                child: DkSettingsGroup(
                  children: [
                    DkSettingsRow(
                      icon: DkIcons.lockedFolder,
                      title: l.files_locked_folder,
                      onTap: () => context.push(Routes.lockedFolder),
                    ),
                    DkSettingsRow(
                      icon: DkIcons.trash,
                      title: l.files_recently_deleted,
                      value: trash > 0 ? '$trash' : null,
                      onTap: () => context.push(Routes.trash),
                    ),
                  ],
                ),
              ),
            ),
            if (loading)
              SliverPadding(
                padding: EdgeInsets.only(top: t.space.xl),
                sliver: SliverToBoxAdapter(child: DkSkeleton.fileRows()),
              )
            else if (empty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DkEmptyStates.filesRoot(
                  context,
                  onScan: () => context.push(Routes.scan),
                  onOpenFile: () => openFileFromDevice(context, ref),
                ),
              )
            else ...[
              if (folders.value!.isNotEmpty) ...[
                _Header(l.files_folders),
                _FolderList(folders: folders.value!, grid: view.grid),
              ],
              if (files.value!.isNotEmpty) ...[
                _Header(l.files_files),
                _FileList(files: files.value!, grid: view.grid),
              ],
              SliverToBoxAdapter(child: SizedBox(height: t.space.xl)),
            ],
          ],
        ),
      ),
    );
  }

  void _sortMenu(
    BuildContext anchor,
    AppLocalizations l,
    FilesView view,
    Prefs prefs,
  ) => showDkMenu(
    anchor,
    groups: [
      [
        for (final (sort, label) in [
          (FileSort.modified, l.files_sort_modified),
          (FileSort.name, l.files_sort_name),
          (FileSort.size, l.files_sort_size),
          (FileSort.created, l.files_sort_created),
        ])
          DkAction(
            label: label,
            checked: view.sort == sort,
            onTap: () => prefs.set('files.sort', sort.name),
          ),
      ],
      [
        DkAction(
          label: l.files_sort_ascending,
          checked: !view.descending,
          onTap: () => prefs.set('files.descending', false),
        ),
        DkAction(
          label: l.files_sort_descending,
          checked: view.descending,
          onTap: () => prefs.set('files.descending', true),
        ),
      ],
    ],
  );
}

/// New folder (DK-0273; §16.4): a name, "Create"; a taken name says so.
Future<void> newFolder(
  BuildContext context,
  WidgetRef ref, {
  int? parent,
}) async {
  final l = AppLocalizations.of(context);
  final db = ref.read(appDatabaseProvider);
  final store = await ref.read(fileStoreProvider.future);
  if (!context.mounted) return;
  await showDkTextDialog(
    context,
    title: l.files_new_folder,
    action: l.files_create,
    hint: l.files_folder_name,
    validate: (name) async {
      try {
        await store.createFolder(db, name, parent: parent);
        return null;
      } on FolderNameException catch (e) {
        return switch (e.problem) {
          FolderNameProblem.taken => l.files_folder_exists,
          FolderNameProblem.invalid => l.files_folder_name,
        };
      }
    },
  );
}

/// A section header ("Folders", "Files"): `titleS`, 24 above, 8 below.
class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(t.space.l, t.space.xl, t.space.s, t.space.s),
      sliver: SliverToBoxAdapter(
        child: Semantics(
          header: true,
          child: Text(
            text,
            style: t.text.titleS.copyWith(color: t.color.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Two per row in the grid, so a card's height follows its text.
Widget _rows(int count, Widget Function(int i) item, {required bool grid}) {
  return Builder(
    builder: (context) {
      final t = context.tokens;
      if (!grid) {
        return SliverList.builder(
          itemCount: count,
          itemBuilder: (_, i) => item(i),
        );
      }
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: t.space.l),
        sliver: SliverList.builder(
          itemCount: (count + 1) ~/ 2,
          itemBuilder: (_, row) => Padding(
            padding: EdgeInsets.only(bottom: t.space.m),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: t.space.m,
              children: [
                Expanded(child: item(row * 2)),
                Expanded(
                  child: row * 2 + 1 < count
                      ? item(row * 2 + 1)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _FolderList extends StatelessWidget {
  const _FolderList({required this.folders, required this.grid});

  final List<FolderCount> folders;
  final bool grid;

  @override
  Widget build(BuildContext context) => _rows(folders.length, (i) {
    final (:folder, :files) = folders[i];
    return DkFolderCard(
      name: folder.name,
      files: files,
      grid: grid,
      tag: DkFolderTag.values.asNameMap()[folder.colourTag],
      onTap: () => context.push(Routes.folder(folder.id)),
    );
  }, grid: grid);
}

class _FileList extends StatelessWidget {
  const _FileList({required this.files, required this.grid});

  final List<FileEntry> files;
  final bool grid;

  @override
  Widget build(BuildContext context) => _rows(
    files.length,
    (i) => FileEntryCard(files[i], grid: grid),
    grid: grid,
  );
}

/// A file's card in F1 and Home: its first page, name and meta; a tap
/// records it in Recent and opens it in V1.
class FileEntryCard extends ConsumerWidget {
  const FileEntryCard(this.file, {super.key, this.grid = false});

  final FileEntry file;
  final bool grid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    // 2× the card's thumbnail width, for sharp pixels on most phones.
    final thumb = ref.watch(fileThumbnailProvider(file.path, grid ? 360 : 96));
    return DkFileCard(
      name: file.name,
      meta: fileMeta(file, l, locale),
      variant: grid ? DkFileCardVariant.grid : DkFileCardVariant.list,
      encrypted: file.encrypted,
      thumbnail: switch (thumb) {
        AsyncData(:final value) => RawImage(image: value, fit: BoxFit.cover),
        // A file PDFium can't render (damaged, or a test without it): a
        // blank page rather than a skeleton forever.
        AsyncError() => ColoredBox(color: context.tokens.color.pageWhite),
        _ => null,
      },
      onTap: () {
        recordOpened(ref.read(appDatabaseProvider), file.id);
        context.push(Routes.viewer('${file.id}'));
      },
    );
  }
}

/// "2.4 MB · 12 pages · Today 14:32" (UI spec §11.2).
String fileMeta(
  FileEntry file,
  AppLocalizations l,
  String locale, {
  DateTime? now,
}) {
  return [
    formatBytes(file.size, locale),
    if (file.pages > 0) l.meta_pages(file.pages),
    formatWhen(file.modified, l, locale, now: now),
  ].join(' · ');
}
