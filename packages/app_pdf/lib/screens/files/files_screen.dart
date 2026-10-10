import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_action_sheet.dart';
import '../../components/dk_banner.dart';
import '../../components/dk_file_card.dart';
import '../../components/dk_folder_card.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_menu.dart';
import '../../components/dk_page_chip.dart';
import '../../components/dk_refresh.dart';
import '../../components/dk_settings_row.dart';
import '../../components/dk_skeleton.dart';
import '../../components/dk_text_field.dart';
import '../../components/dk_confirm_dialog.dart';
import '../../components/dk_tappable.dart';
import '../../components/dk_text_action.dart';
import '../../components/dk_toast.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/formats.dart';
import '../../patterns/dk_empty_states.dart';
import '../../patterns/dk_file_actions.dart';
import '../../patterns/dk_open_file.dart';
import '../../patterns/dk_text_dialog.dart';
import '../../providers/database_providers.dart';
import '../../providers/file_providers.dart';
import '../../providers/files_providers.dart';
import '../../providers/prefs_providers.dart';
import '../../routes/routes.dart';
import '../../theme/dk_folder_tags.dart';
import '../../theme/dk_tokens.dart';
import 'file_preview_pane.dart';

/// F1 · Files, the root (DK-0260; UI spec §16.1): the large top bar with the
/// view toggle, sort and New folder; the search field; the Locked folder and
/// Recently deleted rows; the folders, then the files, as a list or a
/// 2-column grid. Pull to refresh re-scans the user folder. The view and
/// the sort persist ([Prefs]).
///
/// With a [folder], the folder screen (DK-0262), pushed within the tab: the
/// small top bar with its name and the folder menu (Rename folder, Colour,
/// Delete folder), the breadcrumb, and the same content without the special
/// rows.
class FilesScreen extends ConsumerWidget {
  const FilesScreen({super.key, this.folder});

  final int? folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final view = ref.watch(filesViewProvider);
    final folders = ref.watch(foldersProvider(folder));
    final files = ref.watch(filesInProvider(folder));
    if (folder != null) {
      return _FolderScreen(
        id: folder!,
        view: view,
        folders: folders,
        files: files,
      );
    }
    final trash = ref.watch(trashCountProvider).value ?? 0;
    final query = ref.watch(filesQueryProvider);
    final favourites = ref.watch(favouriteFilesProvider).value ?? const [];
    final prefs = ref.read(prefsProvider.notifier);

    final loading = !folders.hasValue || !files.hasValue;
    final empty = !loading && folders.value!.isEmpty && files.value!.isEmpty;
    // A large tablet: the list (360) and the preview pane (DK-0279, §30).
    final wide = MediaQuery.sizeOf(context).width >= _twoPaneFrom;
    final grid = view.grid && !wide;

    final list = Scaffold(
      backgroundColor: t.color.background,
      body: DkRefresh(
        onRefresh: () async {
          final store = await ref.read(fileStoreProvider.future);
          await store.reconcile(ref.read(appDatabaseProvider));
        },
        child: CustomScrollView(
          slivers: [
            // Searching, the field moves up in the title's place (the
            // files-search frame; §16.2 "Search field focused at top").
            if (query.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.paddingOf(context).top + t.space.xl,
                ),
              )
            else
              DkLargeTopBar(
                title: l.shell_tab_files,
                actions: [
                  if (!wide)
                    DkTopBarAction(
                      icon: view.grid ? DkIcons.listView : DkIcons.gridView,
                      tooltip: view.grid
                          ? l.files_list_view
                          : l.files_grid_view,
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
                child: _SearchBar(
                  // Home's search action opens F1 with the field focused.
                  autofocus:
                      GoRouterState.of(context).uri.queryParameters['search'] ==
                      '1',
                ),
              ),
            ),
            if (query.isNotEmpty)
              _SearchResults(query)
            else ...[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  t.space.l,
                  t.space.s,
                  t.space.l,
                  0,
                ),
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
                  hasScrollBody:
                      true, // DkEmptyState centres and scrolls itself
                  child: DkEmptyStates.filesRoot(
                    context,
                    onScan: () => context.push(Routes.scan),
                    onOpenFile: () => openFileFromDevice(context, ref),
                  ),
                )
              else ...[
                // Favourites float to the top (DK-0280).
                if (favourites.isNotEmpty) ...[
                  _Header(l.files_favourites),
                  _FileList(files: favourites, grid: grid),
                ],
                if (folders.value!.isNotEmpty) ...[
                  _Header(l.files_folders),
                  _FolderList(folders: folders.value!, grid: grid),
                ],
                if (files.value!.isNotEmpty) ...[
                  _Header(l.files_files),
                  _FileList(files: files.value!, grid: grid),
                ],
                SliverToBoxAdapter(child: SizedBox(height: t.space.xl)),
              ],
            ],
          ],
        ),
      ),
    );
    if (!wide) return list;
    return _TwoPanes(files: files.value ?? const [], list: list);
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

/// A section header ("Folders", "Files"): `titleS`, 24 above, 8 below;
/// [trailing] on the right ("4 files" in a folder).
class _Header extends StatelessWidget {
  const _Header(this.text, {this.trailing, this.top});
  final String text;
  final String? trailing;
  final double? top;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        t.space.l,
        top ?? t.space.xl,
        t.space.s,
        t.space.s,
      ),
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
            if (trailing != null)
              Text(
                trailing!,
                style: t.text.caption.copyWith(color: t.color.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

/// The folder screen (DK-0262): its chain gives the title and breadcrumb.
class _FolderScreen extends ConsumerWidget {
  const _FolderScreen({
    required this.id,
    required this.view,
    required this.folders,
    required this.files,
  });

  final int id;
  final FilesView view;
  final AsyncValue<List<FolderCount>> folders;
  final AsyncValue<List<FileEntry>> files;

  void _leave(BuildContext context) =>
      context.canPop() ? context.pop() : context.go(Routes.files);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final chain = ref.watch(folderChainProvider(id)).value;
    final loading = chain == null || !folders.hasValue || !files.hasValue;
    final empty = !loading && folders.value!.isEmpty && files.value!.isEmpty;
    final name = chain == null || chain.isEmpty ? '' : chain.last.name;
    return Scaffold(
      backgroundColor: t.color.background,
      appBar: DkTopBar(
        title: name,
        onLeading: () => _leave(context),
        onOverflow: chain == null || chain.isEmpty
            ? null
            : (anchor) => _menu(anchor, ref, chain.last),
      ),
      body: DkRefresh(
        onRefresh: () async {
          final store = await ref.read(fileStoreProvider.future);
          await store.reconcile(ref.read(appDatabaseProvider));
        },
        child: CustomScrollView(
          slivers: [
            if (chain != null && chain.isNotEmpty)
              SliverToBoxAdapter(child: _Breadcrumb(chain)),
            if (loading)
              SliverPadding(
                padding: EdgeInsets.only(top: t.space.l),
                sliver: SliverToBoxAdapter(child: DkSkeleton.fileRows()),
              )
            else if (empty)
              SliverFillRemaining(
                hasScrollBody: true, // DkEmptyState centres and scrolls itself
                child: DkEmptyStates.folder(
                  context,
                  // ponytail: Files' root until the Move sheet (DK-0274)
                  onMove: () => context.go(Routes.files),
                ),
              )
            else ...[
              if (folders.value!.isNotEmpty) ...[
                _Header(l.files_folders, top: t.space.s),
                _FolderList(folders: folders.value!, grid: view.grid),
              ],
              if (files.value!.isNotEmpty) ...[
                _Header(
                  l.files_files,
                  trailing: l.meta_files(files.value!.length),
                  top: folders.value!.isEmpty ? t.space.s : null,
                ),
                _FileList(files: files.value!, grid: view.grid),
              ],
              SliverToBoxAdapter(child: SizedBox(height: t.space.xl)),
            ],
          ],
        ),
      ),
    );
  }

  /// Rename folder · Colour · Delete folder (UI spec §16.1).
  void _menu(BuildContext anchor, WidgetRef ref, Folder folder) {
    final l = AppLocalizations.of(anchor);
    showDkMenu(
      anchor,
      groups: [
        [
          DkAction(
            icon: DkIcons.rename,
            label: l.folder_rename,
            onTap: () => _rename(anchor, ref, folder),
          ),
          // The colours right in the menu, as the files-foldermenu frame;
          // the row itself opens the named list (with No colour).
          DkAction(
            icon: DkIcons.palette,
            label: l.folder_colour,
            onTap: () => _colour(anchor, ref, folder),
            below: _Swatches(
              selected: DkFolderTag.values.asNameMap()[folder.colourTag],
              onPick: (tag) => _setTag(ref, folder, tag),
            ),
          ),
        ],
        [
          DkAction(
            icon: DkIcons.delete,
            label: l.folder_delete,
            destructive: true,
            onTap: () => _delete(anchor, ref, folder),
          ),
        ],
      ],
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
  ) async {
    final l = AppLocalizations.of(context);
    final db = ref.read(appDatabaseProvider);
    final store = await ref.read(fileStoreProvider.future);
    if (!context.mounted) return;
    await showDkTextDialog(
      context,
      title: l.folder_rename,
      action: l.common_rename,
      hint: l.files_folder_name,
      initial: folder.name,
      validate: (name) async {
        try {
          await store.renameFolder(db, folder.id, name);
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

  Future<void> _setTag(WidgetRef ref, Folder folder, DkFolderTag? tag) {
    final db = ref.read(appDatabaseProvider);
    return (db.update(db.folders)..where((f) => f.id.equals(folder.id))).write(
      FoldersCompanion(colourTag: Value(tag?.name)),
    );
  }

  void _colour(BuildContext anchor, WidgetRef ref, Folder folder) {
    final l = AppLocalizations.of(anchor);
    Future<void> set(DkFolderTag? tag) => _setTag(ref, folder, tag);
    showDkMenu(
      anchor,
      groups: [
        [
          for (final (tag, label) in [
            (DkFolderTag.blue, l.folder_tag_blue),
            (DkFolderTag.green, l.folder_tag_green),
            (DkFolderTag.orange, l.folder_tag_orange),
            (DkFolderTag.red, l.folder_tag_red),
            (DkFolderTag.purple, l.folder_tag_purple),
            (DkFolderTag.grey, l.folder_tag_grey),
          ])
            DkAction(
              label: label,
              checked: folder.colourTag == tag.name,
              trailing: Icon(DkIcons.folder, color: tag.colour),
              onTap: () => set(tag),
            ),
        ],
        [
          DkAction(
            label: l.folder_tag_none,
            checked: folder.colourTag == null,
            onTap: () => set(null),
          ),
        ],
      ],
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
  ) async {
    final l = AppLocalizations.of(context);
    final db = ref.read(appDatabaseProvider);
    final store = await ref.read(fileStoreProvider.future);
    final count = await store.countFilesInTree(db, folder.id);
    if (!context.mounted) return;
    if (count > 0 &&
        !await showDkConfirm(
          context,
          title: l.folder_delete_title(folder.name),
          body: l.folder_delete_body(count),
          action: l.folder_delete,
          destructive: true,
          icon: DkIcons.delete,
        )) {
      return;
    }
    await store.deleteFolder(db, folder.id);
    if (context.mounted) _leave(context);
  }
}

/// "Files › Taxes › 2026" (`type.caption`): every part but the last opens
/// that level.
class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb(this.chain);
  final List<Folder> chain;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final style = t.text.caption.copyWith(color: c.textSecondary);
    final parts = <(String, String?)>[
      (l.shell_tab_files, Routes.files),
      for (final (i, f) in chain.indexed)
        (f.name, i == chain.length - 1 ? null : Routes.folder(f.id)),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.space.l),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: t.space.xs,
        children: [
          for (final (i, (label, location)) in parts.indexed) ...[
            if (i > 0)
              ExcludeSemantics(
                child: Text('›', style: style),
              ), // l10n-ignore: a separator
            if (location == null)
              Text(
                label,
                style: style.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              DkTextAction(label: label, onTap: () => context.go(location)),
          ],
        ],
      ),
    );
  }
}

/// Two per row in the grid on a phone, four from 600 dp (a tablet, UI spec
/// §30); rows, so a card's height follows its text.
Widget _rows(int count, Widget Function(int i) item, {required bool grid}) {
  return SliverLayoutBuilder(
    builder: (context, box) {
      final t = context.tokens;
      if (!grid) {
        return SliverList.builder(
          itemCount: count,
          itemBuilder: (_, i) => item(i),
        );
      }
      final per = box.crossAxisExtent >= 600 ? 4 : 2;
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: t.space.l),
        sliver: SliverList.builder(
          itemCount: (count + per - 1) ~/ per,
          itemBuilder: (_, row) => Padding(
            padding: EdgeInsets.only(bottom: t.space.m),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: t.space.m,
              children: [
                for (var i = row * per; i < row * per + per; i++)
                  Expanded(
                    child: i < count ? item(i) : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _FolderList extends ConsumerWidget {
  const _FolderList({required this.folders, required this.grid});

  final List<FolderCount> folders;
  final bool grid;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      _rows(folders.length, (i) {
        final (:folder, :files) = folders[i];
        Widget card({bool hovered = false}) => DkFolderCard(
          name: folder.name,
          files: files,
          grid: grid,
          dropTarget: hovered,
          tag: DkFolderTag.values.asNameMap()[folder.colourTag],
          onTap: () => context.push(Routes.folder(folder.id)),
        );
        if (!grid) return card();
        // Grid: a file card dropped here moves into it (DK-0264); the
        // card shows the 2 dp ring while one hovers.
        return DragTarget<FileEntry>(
          onWillAcceptWithDetails: (d) {
            final ok = d.data.folderId != folder.id;
            // "Drop on “Apartment” to move" while over it (files-dragfolder).
            if (ok) {
              showDkToast(
                context,
                AppLocalizations.of(context).files_drop_hint(folder.name),
              );
            }
            return ok;
          },
          onLeave: (_) => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          onAcceptWithDetails: (d) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            HapticFeedback.lightImpact();
            moveFilesTo(context, ref, [d.data], folder.id);
          },
          builder: (context, hovering, _) => card(hovered: hovering.isNotEmpty),
        );
      }, grid: grid);
}

class _FileList extends StatelessWidget {
  const _FileList({required this.files, required this.grid});

  final List<FileEntry> files;
  final bool grid;

  @override
  Widget build(BuildContext context) => _rows(files.length, (i) {
    final card = FileEntryCard(files[i], grid: grid);
    if (!grid) return card;
    // Grid: long-press and drag onto a folder card (DK-0264).
    return LayoutBuilder(
      builder: (context, box) => LongPressDraggable<FileEntry>(
        data: files[i],
        // The card's own width; its height is its own (rows are unbounded).
        feedback: SizedBox(
          width: box.maxWidth,
          child: Material(type: MaterialType.transparency, child: card),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: card),
        child: card,
      ),
    );
  }, grid: grid);
}

/// A file's card in F1 and Home: its first page, name and meta; a tap
/// records it in Recent and opens it in V1.
class FileEntryCard extends ConsumerWidget {
  const FileEntryCard(
    this.file, {
    super.key,
    this.grid = false,
    this.longPressActions = false,
    this.nameMatch,
    this.hit,
  });

  final bool longPressActions;

  /// Search (DK-0269): the part of the name in bold.
  final String? nameMatch;

  /// Search: the matching page; the card shows its sentence and opens there.
  final TextHit? hit;

  final FileEntry file;
  final bool grid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    // 2× the card's thumbnail width, for sharp pixels on most phones.
    final thumb = ref.watch(fileThumbnailProvider(file.path, grid ? 360 : 96));
    final t = context.tokens;
    final hit = this.hit;
    void open({int? page}) {
      recordOpened(ref.read(appDatabaseProvider), file.id);
      // A text hit opens V1 searching the same words (DK-1093).
      context.push(
        Routes.viewer(
          '${file.id}',
          page: page,
          query: hit == null ? null : ref.read(filesQueryProvider),
        ),
      );
    }

    // A large tablet's list: a tap selects for the preview pane (DK-0279).
    final pane = grid ? null : FilesPane.maybeOf(context);
    final card = DkFileCard(
      name: file.name,
      // A text hit's meta leaves the date out: the sentence says more.
      meta: hit == null
          ? fileMeta(file, l, locale)
          : [
              formatBytes(file.size, locale),
              if (file.pages > 0) l.meta_pages(file.pages),
            ].join(' · '),
      nameMatch: nameMatch,
      extra: hit == null
          ? null
          : Padding(
              padding: EdgeInsets.only(top: t.space.xxs),
              child: Row(
                spacing: t.space.s,
                children: [
                  Expanded(
                    child: Text.rich(
                      snippetSpan(hit.snippet, t.markup),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.text.bodyM.copyWith(color: t.color.textPrimary),
                    ),
                  ),
                  DkPageChip(
                    page: hit.page,
                    onTap: () => open(page: hit.page),
                  ),
                ],
              ),
            ),
      extraLabel: hit?.snippet.replaceAll(RegExp(r'[\[\]]'), ''),
      variant: grid ? DkFileCardVariant.grid : DkFileCardVariant.list,
      encrypted: file.encrypted,
      thumbnail: switch (thumb) {
        AsyncData(:final value) => RawImage(image: value, fit: BoxFit.cover),
        // A file PDFium can't render (damaged, or a test without it): a
        // blank page rather than a skeleton forever.
        AsyncError() => ColoredBox(color: context.tokens.color.pageWhite),
        _ => null,
      },
      onTap: pane == null
          ? () => open(page: hit?.page)
          : () => pane.onSelect(file),
      onMore: () => showFileActions(context, ref, file),
      // Home: a long-press opens the same sheet (§15.1); F1's long-press
      // selects (DK-0263).
      onLongPress: longPressActions
          ? () => showFileActions(context, ref, file)
          : null,
    );
    if (pane == null || pane.selected != file.id) return card;
    return Semantics(
      selected: true,
      child: ColoredBox(
        color: t.color.primaryContainer.withValues(alpha: 0.6),
        child: card,
      ),
    );
  }
}

/// From this width F1 is two panes (UI spec §30, Expanded).
const _twoPaneFrom = 840.0;

/// Two panes (DK-0279): F1's list at 360, the [FilePreviewPane] beside it.
/// A tap on a file selects it (no navigation); the arrow keys move the
/// selection. The first file is selected to start with.
class _TwoPanes extends StatefulWidget {
  const _TwoPanes({required this.files, required this.list});

  final List<FileEntry> files;
  final Widget list;

  @override
  State<_TwoPanes> createState() => _TwoPanesState();
}

class _TwoPanesState extends State<_TwoPanes> {
  int? _selected;

  /// The list pane's: the arrow keys work from the start and after a tap.
  final _focus = FocusNode(debugLabel: 'files list');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  FileEntry? get _file {
    final files = widget.files;
    if (files.isEmpty) return null;
    return files.firstWhere(
      (f) => f.id == _selected,
      orElse: () => files.first,
    );
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final step = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => 1,
      LogicalKeyboardKey.arrowUp => -1,
      _ => 0,
    };
    final files = widget.files;
    if (step == 0 || files.isEmpty) return KeyEventResult.ignored;
    final at = files.indexOf(_file!);
    setState(
      () => _selected = files[(at + step).clamp(0, files.length - 1)].id,
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final file = _file;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 360,
          child: Focus(
            focusNode: _focus,
            autofocus: true,
            onKeyEvent: _key,
            child: FilesPane(
              selected: file?.id,
              onSelect: (f) {
                setState(() => _selected = f.id);
                _focus.requestFocus();
              },
              child: widget.list,
            ),
          ),
        ),
        VerticalDivider(width: 1, thickness: 1, color: t.color.outline),
        Expanded(child: FilePreviewPane(file: file)),
      ],
    );
  }
}

/// Inside the two panes: a file row selects instead of opening the viewer.
class FilesPane extends InheritedWidget {
  const FilesPane({
    super.key,
    required this.selected,
    required this.onSelect,
    required super.child,
  });

  final int? selected;
  final ValueChanged<FileEntry> onSelect;

  static FilesPane? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FilesPane>();

  @override
  bool updateShouldNotify(FilesPane oldWidget) =>
      oldWidget.selected != selected;
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

/// A search snippet with its hits in [ ] (`searchText`): the hits on
/// `markup.yellow` in `markup.black`, the same in both themes.
TextSpan snippetSpan(String snippet, DkMarkup markup) {
  final parts = snippet.split(RegExp(r'[\[\]]'));
  return TextSpan(
    children: [
      for (final (i, p) in parts.indexed)
        if (p.isNotEmpty)
          TextSpan(
            text: p,
            style: i.isOdd
                ? TextStyle(backgroundColor: markup.yellow, color: markup.black)
                : null,
          ),
    ],
  );
}

/// F1's search field, with Cancel while it holds a query (§16.1).
class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar({required this.autofocus});

  final bool autofocus;

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  late final _controller = TextEditingController(
    text: ref.read(filesQueryProvider),
  );
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final searching = ref.watch(filesQueryProvider).isNotEmpty;
    return Row(
      spacing: context.tokens.space.xs,
      children: [
        Expanded(
          child: DkSearchField(
            hint: l.files_search_hint,
            controller: _controller,
            focusNode: _focus,
            autofocus: widget.autofocus,
            onChanged: ref.read(filesQueryProvider.notifier).set,
          ),
        ),
        if (searching)
          DkTextAction(
            label: l.common_cancel,
            onTap: () {
              _controller.clear();
              _focus.unfocus();
              ref.read(filesQueryProvider.notifier).set('');
            },
          ),
      ],
    );
  }
}

/// Search results (DK-0269; UI spec §16.2): the no-text banner when nothing
/// matches and some files have no text layer; "Names" with the match in bold; "Text inside
/// files" with the sentence and its page; ILL-07 when nothing matches.
class _SearchResults extends ConsumerWidget {
  const _SearchResults(this.query);

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final found = ref.watch(fileSearchProvider(query)).value;
    if (found == null) {
      return SliverPadding(
        padding: EdgeInsets.only(top: t.space.l),
        sliver: SliverToBoxAdapter(child: DkSkeleton.fileRows()),
      );
    }
    final banner = found.unsearchable == 0
        ? null
        : SliverPadding(
            padding: EdgeInsets.fromLTRB(t.space.l, t.space.s, t.space.l, 0),
            sliver: SliverToBoxAdapter(
              child: DkBanner(
                icon: DkIcons.noText,
                text: l.banner_no_text(found.unsearchable),
                action: l.banner_make_searchable,
                // ponytail: no Pro badge until the paywall's entitlement
                // exists; the OCR tool asks for Pro itself.
                onAction: () => context.push(Routes.tool('ocr')),
              ),
            ),
          );
    // The banner comes with no results only (§16.2, files-searchempty).
    if (found.names.isEmpty && found.text.isEmpty) {
      return SliverMainAxisGroup(
        slivers: [
          ?banner,
          SliverFillRemaining(
            hasScrollBody: true, // DkEmptyState centres and scrolls itself
            child: DkEmptyStates.search(context, query: query),
          ),
        ],
      );
    }
    return SliverMainAxisGroup(
      slivers: [
        if (found.names.isNotEmpty) ...[
          _Header(l.search_names),
          SliverList.builder(
            itemCount: found.names.length,
            itemBuilder: (_, i) =>
                FileEntryCard(found.names[i], nameMatch: query),
          ),
        ],
        if (found.text.isNotEmpty) ...[
          _Header(l.search_text),
          SliverList.builder(
            itemCount: found.text.length,
            itemBuilder: (_, i) =>
                FileEntryCard(found.text[i].file, hit: found.text[i]),
          ),
        ],
        SliverToBoxAdapter(child: SizedBox(height: t.space.xl)),
      ],
    );
  }
}

/// The six folder colours in a row (the folder menu): a tap picks one and
/// closes the menu; the chosen one has a ring.
class _Swatches extends StatelessWidget {
  const _Swatches({required this.selected, required this.onPick});

  final DkFolderTag? selected;
  final ValueChanged<DkFolderTag> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final names = {
      DkFolderTag.blue: l.folder_tag_blue,
      DkFolderTag.green: l.folder_tag_green,
      DkFolderTag.orange: l.folder_tag_orange,
      DkFolderTag.red: l.folder_tag_red,
      DkFolderTag.purple: l.folder_tag_purple,
      DkFolderTag.grey: l.folder_tag_grey,
    };
    return Row(
      spacing: t.space.s,
      children: [
        for (final MapEntry(key: tag, value: name) in names.entries)
          Semantics(
            button: true,
            selected: tag == selected,
            label: name,
            excludeSemantics: true,
            onTap: () {
              Navigator.pop(context);
              onPick(tag);
            },
            child: DkTappable(
              radius: 20,
              onTap: () {
                Navigator.pop(context);
                onPick(tag);
              },
              builder: (context, pressed) => Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tag.colour,
                  border: tag == selected
                      ? Border.all(color: t.color.surface, width: 2)
                      : null,
                  boxShadow: tag == selected
                      ? [BoxShadow(color: tag.colour, spreadRadius: 2)]
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
