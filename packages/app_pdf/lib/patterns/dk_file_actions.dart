import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/dk_action_sheet.dart';
import '../components/dk_button.dart';
import '../components/dk_icon.dart';
import '../theme/dk_folder_tags.dart';
import '../components/dk_tappable.dart';
import '../components/dk_folder_card.dart';
import '../components/dk_sheet.dart';
import '../components/dk_text_action.dart';
import '../l10n/app_localizations.dart';
import '../providers/database_providers.dart';
import '../providers/file_providers.dart';
import '../providers/files_providers.dart';
import '../routes/routes.dart';
import '../screens/files/files_screen.dart' show fileMeta, newFolder;
import '../theme/dk_tokens.dart';
import '../tools/tool_catalogue.dart';
import 'dk_file_info.dart';
import 'dk_text_dialog.dart';
import 'dk_undo.dart';

/// Tools that never take a PDF as their input.
const _notForPdfs = {'scan', 'img2pdf', 'web', 'batch', 'workflows', 'compare'};

/// What the action sheet suggests for a PDF before the user has a history.
const _defaultSuggestions = ['compress', 'sign', 'protect', 'redact', 'ocr'];

/// Up to 5 tools for a PDF: the most used first (tool_usage, DK-0022), then
/// the defaults.
@visibleForTesting
Future<List<String>> suggestedTools(DokuloDatabase db) async {
  final used = await db.mostUsedTools(20).get();
  return {
    ...used.where((id) => !_notForPdfs.contains(id)),
    ..._defaultSuggestions,
  }.take(5).toList();
}

/// The file action sheet (DK-0271; UI spec §16.3), medium: the header; Open
/// and Share; up to 5 suggested tools; All tools…; Rename · Duplicate ·
/// Move · Move to locked folder · Info; Delete.
Future<void> showFileActions(
  BuildContext context,
  WidgetRef ref,
  FileEntry file,
) async {
  final l = AppLocalizations.of(context);
  final db = ref.read(appDatabaseProvider);
  final tools = await suggestedTools(db);
  final favourite =
      await (db.select(
        db.favourites,
      )..where((f) => f.fileId.equals(file.id))).getSingleOrNull() !=
      null;
  if (!context.mounted) return;
  final locale = Localizations.localeOf(context).toLanguageTag();
  void open() {
    recordOpened(db, file.id);
    context.push(Routes.viewer('${file.id}'));
  }

  await showDkActionSheet(
    context,
    header: DkActionSheetHeader(
      thumbnail: Consumer(
        builder: (context, ref, _) => switch (ref.watch(
          fileThumbnailProvider(file.path, 96),
        )) {
          AsyncData(:final value) => RawImage(image: value, fit: BoxFit.cover),
          AsyncError() => ColoredBox(color: context.tokens.color.pageWhite),
          _ => const SizedBox.shrink(),
        },
      ),
      name: file.name,
      meta: fileMeta(file, l, locale),
    ),
    top: Builder(
      builder: (sheet) => Row(
        spacing: sheet.tokens.space.s,
        children: [
          Expanded(
            child: DkButton(
              label: l.common_open,
              icon: DkIcons.open,
              variant: DkButtonVariant.tonal,
              size: DkButtonSize.large,
              expand: true,
              onPressed: () {
                Navigator.pop(sheet);
                open();
              },
            ),
          ),
          Expanded(
            child: DkButton(
              label: l.common_share,
              icon: DkIcons.share(sheet),
              variant: DkButtonVariant.tonal,
              size: DkButtonSize.large,
              expand: true,
              // ponytail: off until share_plus lands (its own deps PR)
              onPressed: null,
            ),
          ),
        ],
      ),
    ),
    groups: [
      [
        for (final id in tools)
          DkAction(
            icon: DkIcons.tool(id),
            label: ToolCatalogue.of(id).name(l),
            tool: true,
            onTap: () => context.push(Routes.tool(id, files: ['${file.id}'])),
          ),
        DkAction(
          icon: DkIcons.toolsTab,
          label: l.file_all_tools,
          onTap: () => context.go(Routes.tools),
        ),
      ],
      [
        DkAction(
          icon: DkIcons.star,
          filled: favourite,
          label: favourite ? l.file_favourite_remove : l.file_favourite_add,
          onTap: () => setFavourite(db, file.id, !favourite),
        ),
        DkAction(
          icon: DkIcons.rename,
          label: l.common_rename,
          onTap: () => renameFile(context, ref, file),
        ),
        DkAction(
          icon: DkIcons.duplicate,
          label: l.common_duplicate,
          onTap: () => duplicateFile(context, ref, file),
        ),
        DkAction(
          icon: DkIcons.move,
          label: l.common_move,
          onTap: () => moveFiles(context, ref, [file]),
        ),
        DkAction(
          icon: DkIcons.lockedFolder,
          label: l.file_move_to_locked,
          // F2 sets up or unlocks first, then seals it (DK-0289).
          onTap: () => context.push(Routes.lockedFolder, extra: [file.id]),
        ),
        DkAction(
          icon: DkIcons.info,
          label: l.common_info,
          onTap: () => showFileInfo(context, file),
        ),
      ],
      [
        DkAction(
          icon: DkIcons.delete,
          label: l.common_delete,
          destructive: true,
          onTap: () => deleteFiles(context, ref, [file]),
        ),
      ],
    ],
  );
}

/// Rename (DK-0272; §16.4): the name without its extension, selected; the
/// extension shown after the field and kept; a taken name says so inline.
Future<void> renameFile(
  BuildContext context,
  WidgetRef ref,
  FileEntry file,
) async {
  final l = AppLocalizations.of(context);
  final db = ref.read(appDatabaseProvider);
  final store = await ref.read(fileStoreProvider.future);
  if (!context.mounted) return;
  final dot = file.name.lastIndexOf('.');
  final stem = dot > 0 ? file.name.substring(0, dot) : file.name;
  await showDkTextDialog(
    context,
    title: l.common_rename,
    action: l.common_rename,
    initial: stem,
    suffix: dot > 0 ? file.name.substring(dot) : null,
    validate: (name) async {
      try {
        await store.renameFile(db, file.id, name);
        return null;
      } on FileNameException catch (e) {
        return switch (e.problem) {
          FileNameProblem.taken => l.file_name_taken,
          FileNameProblem.invalid => l.file_name_invalid,
        };
      }
    },
  );
}

/// Duplicate (DK-0276): "{name} (2).pdf" next to it, with Undo.
Future<void> duplicateFile(
  BuildContext context,
  WidgetRef ref,
  FileEntry file,
) async {
  final l = AppLocalizations.of(context);
  final db = ref.read(appDatabaseProvider);
  final store = await ref.read(fileStoreProvider.future);
  final copy = await store.duplicateFile(db, file.id);
  final name = (await (db.select(
    db.files,
  )..where((f) => f.id.equals(copy))).getSingle()).name;
  if (!context.mounted) return;
  await showDkUndo(
    context,
    DkUndo.move,
    l.toast_duplicated(name),
    onUndo: () => store.deleteCopy(db, copy),
  );
}

/// Delete (§16.4): to Recently deleted at once, with Undo.
Future<void> deleteFiles(
  BuildContext context,
  WidgetRef ref,
  List<FileEntry> files,
) async {
  final l = AppLocalizations.of(context);
  final db = ref.read(appDatabaseProvider);
  final store = await ref.read(fileStoreProvider.future);
  for (final f in files) {
    await store.trashFile(db, f.id);
  }
  if (!context.mounted) return;
  await showDkUndo(
    context,
    DkUndo.deleteToTrash,
    l.toast_moved_trash,
    onUndo: () async {
      for (final f in files) {
        await store.restoreFromTrash(db, f.id);
      }
    },
  );
}

/// The Move sheet (DK-0274; §16.4), large: the folders, the breadcrumb to
/// go back up, "New folder" at the top, and the sticky "Move here". A toast
/// "Moved to {folder}" with Undo puts every file back where it was.
Future<void> moveFiles(
  BuildContext context,
  WidgetRef ref,
  List<FileEntry> files,
) async {
  final l = AppLocalizations.of(context);
  final target = await pickFolder(
    context,
    title: l.file_move_title(files.length),
    action: l.file_move_here,
  );
  if (target == null || !context.mounted) return;
  await moveFilesTo(context, ref, files, target.folder);
}

/// A folder from the Move sheet's browser (T3's Save to…, DK-0385): the
/// folders with the breadcrumb and "New folder", and the sticky [action]
/// ("Move here", "Save here"). With [elsewhere], a second button under it
/// answers `elsewhere: true` (the system's save dialog). Null when closed.
Future<({int? folder, bool elsewhere})?> pickFolder(
  BuildContext context, {
  required String title,
  required String action,
  String? elsewhere,
}) async {
  // The folder the sheet is in; the buttons answer with it.
  final at = ValueNotifier<int?>(null);
  final picked = await showDkSheet<({int? folder, bool elsewhere})>(
    context,
    title: title,
    detent: DkSheetDetent.large,
    showClose: true,
    body: _MoveBrowser(at),
    // Sticky at the bottom, as the files-move frame.
    actions: Builder(
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: sheet.tokens.space.s,
        children: [
          DkButton(
            label: action,
            size: DkButtonSize.large,
            expand: true,
            onPressed: () =>
                Navigator.pop(sheet, (folder: at.value, elsewhere: false)),
          ),
          if (elsewhere != null)
            DkButton(
              label: elsewhere,
              variant: DkButtonVariant.tertiary,
              size: DkButtonSize.large,
              expand: true,
              onPressed: () =>
                  Navigator.pop(sheet, (folder: null, elsewhere: true)),
            ),
        ],
      ),
    ),
  );
  at.dispose();
  return picked;
}

/// Moves [files] into [folder] (null: the root), then "Moved to {folder}"
/// with Undo putting each back (the Move sheet; a drop on a folder card,
/// DK-0264).
Future<void> moveFilesTo(
  BuildContext context,
  WidgetRef ref,
  List<FileEntry> files,
  int? folder,
) async {
  final l = AppLocalizations.of(context);
  final db = ref.read(appDatabaseProvider);
  final store = await ref.read(fileStoreProvider.future);
  final was = <int, int?>{};
  for (final f in files) {
    was[f.id] = await store.moveFile(db, f.id, folder);
  }
  final chain = folder == null
      ? const <Folder>[]
      : await (db.select(db.folders)..where((f) => f.id.equals(folder))).get();
  if (!context.mounted) return;
  await showDkUndo(
    context,
    DkUndo.move,
    l.toast_moved(chain.isEmpty ? l.shell_tab_files : chain.single.name),
    onUndo: () async {
      for (final MapEntry(key: id, value: back) in was.entries) {
        await store.moveFile(db, id, back);
      }
    },
  );
}

/// The folder browser inside the Move sheet.
class _MoveBrowser extends ConsumerStatefulWidget {
  const _MoveBrowser(this.at);

  /// The folder shown (null: the root); the sheet's buttons answer with it.
  final ValueNotifier<int?> at;

  @override
  ConsumerState<_MoveBrowser> createState() => _MoveBrowserState();
}

class _MoveBrowserState extends ConsumerState<_MoveBrowser> {
  int? get _at => widget.at.value;
  void _go(int? folder) => setState(() => widget.at.value = folder);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final folders = ref.watch(foldersProvider(_at)).value ?? const [];
    final chain = _at == null
        ? const <Folder>[]
        : ref.watch(folderChainProvider(_at!)).value ?? const <Folder>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: t.space.xs,
          children: [
            DkTextAction(
              label: l.shell_tab_files,
              onTap: _at == null ? null : () => _go(null),
            ),
            for (final (i, f) in chain.indexed) ...[
              ExcludeSemantics(
                child: Text(
                  '›', // l10n-ignore: a separator
                  style: t.text.caption.copyWith(color: t.color.textSecondary),
                ),
              ),
              DkTextAction(
                label: f.name,
                onTap: i == chain.length - 1 ? null : () => _go(f.id),
              ),
            ],
          ],
        ),
        // New folder in color.primary, as the frame; then the folders as
        // Files lists them (the tag colour, the count, the chevron).
        DkTappable(
          radius: 0,
          onTap: () => newFolder(context, ref, parent: _at),
          builder: (context, pressed) => Padding(
            padding: EdgeInsets.symmetric(vertical: t.space.m),
            child: Row(
              spacing: t.space.m,
              children: [
                DkIcon(DkIcons.newFolder, color: t.color.primary),
                Text(
                  l.files_new_folder,
                  style: t.text.titleS.copyWith(color: t.color.primary),
                ),
              ],
            ),
          ),
        ),
        for (final (:folder, :files) in folders)
          DkFolderCard(
            name: folder.name,
            files: files,
            tag: DkFolderTag.values.asNameMap()[folder.colourTag],
            onTap: () => _go(folder.id),
          ),
      ],
    );
  }
}
