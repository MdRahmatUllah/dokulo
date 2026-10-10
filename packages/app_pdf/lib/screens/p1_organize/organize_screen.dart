import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:ai_core/ai_core.dart' show IsolatePool;

import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_action_sheet.dart';
import '../../components/dk_bottom_bars.dart';
import '../../components/dk_file_card.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_icon_button.dart';
import '../../components/dk_loading_spinner.dart';
import '../../components/dk_page_grid.dart';
import '../../components/dk_segmented.dart';
import '../../components/dk_sheet.dart';
import '../../components/dk_toast.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../patterns/dk_confirmations.dart';
import '../../patterns/dk_open_file.dart';
import '../../providers/database_providers.dart';
import '../../providers/file_providers.dart';
import '../../routes/link_error.dart';
import '../../routes/routes.dart';
import '../../theme/dk_layout.dart';
import '../../theme/dk_tokens.dart';
import '../../theme/haptics.dart';
import '../../tools/tool_catalogue.dart';
import '../../tools/tool_inputs.dart';
import '../t2_tool/tool_options_providers.dart';
import '../v1_viewer/viewer_providers.dart';

/// P1, Organize pages (UI spec §18; DK-0329): the document's pages in
/// DkPageGrid. Drag one to move it (DK-0331); tap or long-press to select,
/// then Rotate · Duplicate · Delete · Extract; + inserts a blank page or
/// another PDF's pages (DK-0332); Undo and Redo step through every edit
/// (doc_core's PageEdit). Save keeps the result as a copy next to the
/// original, which is never touched.
class OrganizeScreen extends ConsumerWidget {
  const OrganizeScreen({super.key, required this.fileId});

  final int fileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(viewerFileProvider(fileId))) {
        AsyncData(:final value) => _Organize(file: value),
        AsyncError() => const LinkErrorScreen(fileMissing: true),
        _ => const Scaffold(body: Center(child: DkLoadingSpinner())),
      };
}

class _Organize extends ConsumerStatefulWidget {
  const _Organize({required this.file});

  final FileEntry file;

  @override
  ConsumerState<_Organize> createState() => _OrganizeState();
}

class _OrganizeState extends ConsumerState<_Organize> {
  PageEdit? _edit;
  var _selected = <int>{};
  var _saving = false;

  /// The thumbnails of the pages the grid has shown, by file and page: a
  /// page is a skeleton with its number until its thumbnail renders, then
  /// fades in (DK-0335). Only the visible pages ask (the grid is
  /// virtualised), so a 300-page document renders as it scrolls.
  final _thumbs = <(String, int), ProviderSubscription<AsyncValue<ui.Image>>>{};

  @override
  void dispose() {
    for (final sub in _thumbs.values) {
      sub.close();
    }
    super.dispose();
  }

  Widget? _thumb(PageSource source) {
    final sub = _thumbs.putIfAbsent(
      (source.path, source.page),
      () => ref.listenManual(
        pdfThumbnailProvider(source.path, page: source.page + 1),
        (_, next) {
          if (next.hasValue && mounted) setState(() {});
        },
      ),
    );
    final image = sub.read().value;
    if (image == null) return null;
    return RotatedBox(
      quarterTurns: source.addQuarterTurns,
      child: RawImage(image: image),
    );
  }

  @override
  void initState() {
    super.initState();
    PdfEngine.inspect(widget.file.path).then((info) {
      if (mounted) {
        setState(() => _edit = PageEdit(widget.file.path, info.pageCount));
      }
    });
  }

  void _do(void Function(PageEdit edit) change) =>
      setState(() => change(_edit!));

  void _toggle(int index) => setState(
    () => _selected = _selected.contains(index)
        ? ({..._selected}..remove(index))
        : {..._selected, index},
  );

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final count = _selected.length;
    // A PDF keeps a page: deleting all of them is not offered.
    if (count >= _edit!.pages.length) return;
    _do((e) => e.delete(_selected));
    setState(() => _selected = {});
    await showDkToast(
      context,
      l.toast_pages_deleted(count),
      action: l.common_undo,
      onAction: () => _do((e) => e.undo()),
    );
  }

  /// The selected pages, in order, as a new file next to the original.
  Future<void> _extract() async {
    final pages = [
      for (final (i, p) in _edit!.pages.indexed)
        if (_selected.contains(i)) p,
    ];
    await _write(
      (out) => PdfEngine.assemble(pages, out),
      suffix: AppLocalizations.of(context).organize_extracted,
    );
  }

  Future<void> _save() async {
    if (_edit!.changed) {
      await _write(_edit!.save);
      if (mounted) context.pop();
    } else {
      context.pop();
    }
  }

  /// Writes with [write] and saves the file next to the original (a free
  /// name for the copy), with "Saved to Files › … · Open".
  Future<void> _write(
    Future<void> Function(String outPath) write, {
    String? suffix,
  }) async {
    final l = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final store = await ref.read(fileStoreProvider.future);
      final out = await store.newTempFile(widget.file.name);
      await write(out.path);
      final name = suffix == null
          ? widget.file.name
          : widget.file.name.replaceFirst(
              RegExp(r'(\.pdf)?$', caseSensitive: false),
              ' – $suffix.pdf',
            );
      final sub = store.subfolderOf(widget.file.path);
      final saved = await store.saveIndexed(
        ref.read(appDatabaseProvider),
        out,
        name: name,
        subfolder: sub,
      );
      await ref.read(hapticsProvider).saved();
      if (!mounted) return;
      final place = [
        l.shell_tab_files,
        ...?sub?.split(Platform.pathSeparator),
      ].join(' › ');
      final router = GoRouter.of(context);
      showDkToast(
        context,
        l.toast_saved_to(place),
        action: l.common_open,
        onAction: () => router.push(Routes.viewer('${saved.id}')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancel() async {
    if (_edit?.changed ?? false) {
      if (!await confirmDk(context, DkConfirmation.discardEdits)) return;
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final edit = _edit;
    final selecting = _selected.isNotEmpty;
    return PopScope(
      canPop: !(edit?.changed ?? false) && !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        selecting ? setState(() => _selected = {}) : _cancel();
      },
      child: Scaffold(
        backgroundColor: t.color.background,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(DkTopBar.height),
          child: selecting
              ? DkTopBar.editing(
                  title: l.common_selected(_selected.length),
                  onCancel: () => setState(() => _selected = {}),
                  onDone: () => setState(
                    () => _selected = {
                      for (var i = 0; i < edit!.pages.length; i++) i,
                    },
                  ),
                  doneLabel: l.common_select_all,
                )
              : DkTopBar.editing(
                  title: ToolCatalogue.of('organize').name(l),
                  onCancel: _cancel,
                  onDone: edit == null || _saving ? null : _save,
                  doneLabel: l.t3_save,
                ),
        ),
        body: edit == null
            ? const Center(child: DkLoadingSpinner())
            : Column(
                children: [
                  _SubBar(
                    count: edit.pages.length,
                    onUndo: edit.canUndo ? () => _do((e) => e.undo()) : null,
                    onRedo: edit.canRedo ? () => _do((e) => e.redo()) : null,
                  ),
                  Expanded(
                    child: DkPageGrid(
                      pageIds: edit.pages,
                      selected: _selected,
                      // A tap selects; a long-press lifts the page only:
                      // mid-drag the screen stays out of selection mode
                      // (organize-drag, DK-0799).
                      onTap: _toggle,
                      onReorder: (from, to) {
                        _do((e) => e.move(from, to));
                        setState(() => _selected = {});
                        ref.read(hapticsProvider).dropped();
                      },
                      // Phones 3 columns, tablets 5 and 8; pinch for 2–6
                      // (DK-0334).
                      initialColumns: switch (DkGrid.forWidth(
                        MediaQuery.sizeOf(context).width,
                      )) {
                        DkGrid.phone => 3,
                        DkGrid.smallTablet => 5,
                        _ => 8,
                      },
                      pageBuilder: (context, i) => _thumb(edit.pages[i]),
                    ),
                  ),
                ],
              ),
        floatingActionButton: selecting || edit == null
            ? null
            // A 56 primary circle with the add icon and the floating shadow
            // (the artboard's FAB, as the Scan button).
            : DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: t.elevation.floating,
                ),
                child: FloatingActionButton(
                  tooltip: l.organize_insert_title,
                  shape: const CircleBorder(),
                  elevation: 0,
                  focusElevation: 0,
                  hoverElevation: 0,
                  highlightElevation: 0,
                  backgroundColor: t.color.primary,
                  foregroundColor: t.color.onPrimary,
                  onPressed: () => _showInsert(edit),
                  child: DkIcon(
                    DkIcons.add,
                    size: DkIconSize.xl,
                    color: t.color.onPrimary,
                  ),
                ),
              ),
        bottomNavigationBar: selecting
            ? DkSelectionBar(
                actions: [
                  DkBarAction(
                    icon: DkIcons.tool('rotate'),
                    label: l.organize_rotate,
                    onPressed: () => _do((e) => e.rotate(_selected, 1)),
                  ),
                  DkBarAction(
                    icon: DkIcons.duplicate,
                    label: l.common_duplicate,
                    onPressed: () {
                      _do((e) => e.duplicate(_selected));
                      setState(() => _selected = {});
                    },
                  ),
                  DkBarAction(
                    icon: DkIcons.delete,
                    label: l.common_delete,
                    destructive: true,
                    onPressed: _selected.length < edit!.pages.length
                        ? _delete
                        : null,
                  ),
                  DkBarAction(
                    icon: DkIcons.tool('extract'),
                    label: l.organize_extract,
                    onPressed: _saving ? null : _extract,
                  ),
                ],
              )
            : null,
      ),
    );
  }

  /// The insert sheet (DK-0332): what to insert, and where.
  Future<void> _showInsert(PageEdit edit) async {
    final l = AppLocalizations.of(context);
    final after = _selected.isEmpty
        ? null
        : _selected.reduce((a, b) => a > b ? a : b);
    var atEnd = after == null;
    String? choice;
    await showDkSheet<void>(
      context,
      title: l.organize_insert_title,
      showClose: true,
      body: StatefulBuilder(
        builder: (context, setSheet) {
          final t = context.tokens;
          // The row closes the sheet, then records the choice.
          Widget row(String key, IconData icon, String label) => DkActionRow(
            DkAction(icon: icon, label: label, onTap: () => choice = key),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row('blank', DkIcons.blankPage, l.organize_insert_blank),
              row('pdf', DkIcons.pdf, l.organize_insert_pdf),
              // From a scan comes with the scanner's review (DK-1082).
              row('photos', DkIcons.importPhotos, l.organize_insert_photos),
              if (after != null) ...[
                SizedBox(height: t.space.m),
                Text(
                  l.organize_insert_position,
                  style: t.text.titleS.copyWith(color: t.color.textPrimary),
                ),
                SizedBox(height: t.space.s),
                DkSegmented<bool>(
                  segments: [
                    (false, l.organize_insert_after(after + 1)),
                    (true, l.organize_insert_end),
                  ],
                  selected: atEnd,
                  onChanged: (v) => setSheet(() => atEnd = v),
                ),
              ],
            ],
          );
        },
      ),
    );
    if (choice == null || !mounted) return;
    final at = atEnd ? edit.pages.length : after! + 1;
    if (choice == 'blank') {
      final store = await ref.read(fileStoreProvider.future);
      await edit.insertBlank(at, store.temp);
      setState(() {});
    } else if (choice == 'photos') {
      final images = [
        for (final p in await ref.read(devicePickerProvider)(
          ToolInput.of('img2pdf')!,
          photos: true,
        ))
          // HEIC needs the platform's decoder first (DK-1081).
          if (ToolInput.kindOf(p) == DkFileKind.image &&
              !RegExp(r'\.hei[cf]$', caseSensitive: false).hasMatch(p))
            p,
      ];
      if (images.isEmpty || !mounted) return;
      final store = await ref.read(fileStoreProvider.future);
      final pdf = await store.newTempFile('photos.pdf');
      // One page per photo, as Image to PDF makes them, off the UI isolate.
      await Isolate.run(() => _photosPdf(images, pdf.path));
      final info = await PdfEngine.inspect(pdf.path);
      _do(
        (e) => e.insert(at, [
          for (var i = 0; i < info.pageCount; i++) PageSource(pdf.path, i),
        ]),
      );
    } else {
      final path = await ref.read(pickPdfProvider)();
      if (path == null || !mounted) return;
      final store = await ref.read(fileStoreProvider.future);
      final copy = await store.importIncoming(File(path));
      final info = await PdfEngine.inspect(copy.path);
      _do(
        (e) => e.insert(at, [
          for (var i = 0; i < info.pageCount; i++) PageSource(copy.path, i),
        ]),
      );
    }
  }
}

/// "12 pages" with Undo and Redo (UI spec §18).
class _SubBar extends StatelessWidget {
  const _SubBar({required this.count, this.onUndo, this.onRedo});

  final int count;
  final VoidCallback? onUndo, onRedo;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.space.l),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l.meta_pages(count),
              style: t.text.labelM.copyWith(color: t.color.textSecondary),
            ),
          ),
          DkIconButton(
            icon: DkIcons.undo,
            tooltip: l.common_undo,
            onPressed: onUndo,
          ),
          DkIconButton(
            icon: DkIcons.redo,
            tooltip: l.common_redo,
            onPressed: onRedo,
          ),
        ],
      ),
    );
  }
}

/// [images] as a PDF at [output] (Fit image, no margins), on a worker.
Future<void> _photosPdf(List<String> images, String output) async {
  final work = Directory.systemTemp.createTempSync('dk_photos_');
  try {
    final writer = ImagesPdfWriter(output, workDir: work);
    for (final image in images) {
      await writer.add(File(image).readAsBytesSync());
    }
    await writer.close(IsolatePool(tempRoot: work));
  } finally {
    work.deleteSync(recursive: true);
  }
}
