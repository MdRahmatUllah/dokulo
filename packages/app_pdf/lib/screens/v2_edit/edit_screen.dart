import 'dart:io';

import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_editor_bars.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_pdf_canvas.dart';
import '../../components/dk_toast.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../patterns/dk_confirmations.dart';
import '../../providers/file_providers.dart';
import '../../providers/files_providers.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';
import '../sign/signatures_sheet.dart';
import '../v1_viewer/viewer_providers.dart';
import 'annotation_editor.dart';
import 'annotation_overlay.dart';

/// The tool strip's items, in the spec's order (UI spec §17.2): the
/// editor's tools, with Sign (it opens the signatures sheet) before Eraser.
const _strip = <EditTool?>[
  EditTool.pan,
  EditTool.pen,
  EditTool.highlighter,
  EditTool.text,
  EditTool.shapes,
  EditTool.note,
  null, // Sign
  EditTool.eraser,
];

/// V2, edit mode (DK-0313; UI spec §17.2, design `07-edit/*`): the editing
/// top bar ("Editing", Cancel, Done), the pages at full brightness under a
/// 2 dp `color.primary` line that says edit mode is on, each page's
/// [AnnotationOverlay], and DkToolStrip (Pan · Pen · Highlighter · Text ·
/// Shapes · Note · Sign · Eraser | Undo · Redo). Pan scrolls and zooms; the
/// other tools draw, and the pages stay put.
///
/// Done writes the annotations into a new copy, keeps what the file was as
/// a version (Info → Versions) and says "Saved · Undo". Cancel (or back)
/// with changes asks "Discard your changes?" first; without, it just
/// leaves. Reading mode (V1) never creates marks. [fromSign]: entered from
/// Sign, so Pan is selected and the signatures sheet opens.
class EditScreen extends ConsumerStatefulWidget {
  const EditScreen({super.key, required this.fileId, this.fromSign = false});

  final int fileId;
  final bool fromSign;

  @override
  ConsumerState<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends ConsumerState<EditScreen> {
  AnnotationEditor? _editor;
  FileEntry? _file;

  /// What the canvas shows: a copy, so the file itself is never held open
  /// while Done replaces it.
  String? _view;
  var _selected = 0; // Pan
  var _saving = false;

  /// The file's row is gone (deleted, or a stale link).
  var _missing = false;
  final _style = const EditStyle();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _editor?.dispose();
    super.dispose();
  }

  /// The file and the annotations already in it, page by page.
  Future<void> _load() async {
    final FileEntry file;
    try {
      file = await ref.read(viewerFileProvider(widget.fileId).future);
    } on StateError {
      if (mounted) setState(() => _missing = true);
      return;
    }
    final store = await ref.read(fileStoreProvider.future);
    final view = await store.newTempFile('view-${file.name}');
    await File(file.path).copy(view.path);
    final info = await PdfEngine.inspect(file.path);
    final read = <int, List<PageAnnot>>{
      for (var p = 0; p < info.pageCount; p++)
        p: await PdfAnnotations.read(file.path, p),
    };
    if (!mounted) return;
    setState(() {
      _file = file;
      _view = view.path;
      _editor = AnnotationEditor(read: read)..tool = EditTool.pan;
    });
    if (widget.fromSign) await _sign();
  }

  void _select(int index) {
    final tool = _strip[index];
    if (tool == null) {
      _sign();
      return;
    }
    setState(() => _selected = index);
    _editor!.tool = tool;
  }

  /// Sign: Pan, and the signatures sheet. ponytail: placing the chosen
  /// signature on the page is DK-0328.
  Future<void> _sign() async {
    setState(() => _selected = 0);
    _editor!.tool = EditTool.pan;
    await showSignaturesSheet(context);
  }

  Future<void> _cancel() async {
    if (_editor?.dirty ?? false) {
      if (!await confirmDk(context, DkConfirmation.discardEdits)) return;
    }
    if (mounted) _leave();
  }

  void _leave() => context.canPop()
      ? context.pop()
      : context.go(Routes.viewer('${widget.fileId}'));

  /// Done: the annotations into a new copy that replaces the file, the old
  /// content kept as a version; "Saved · Undo" puts it back.
  Future<void> _done() async {
    final editor = _editor!, file = _file!;
    final l = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final store = await ref.read(fileStoreProvider.future);
      final out = await store.newTempFile(
        file.path.split(RegExp(r'[\\/]')).last,
      );
      await PdfAnnotations.apply(file.path, out.path, editor.edits());
      final versions = await ref.read(versionStoreProvider.future);
      final before = await versions.replace(widget.fileId, out.path);
      if (!mounted) return;
      showDkToast(
        context,
        l.toast_saved,
        action: l.common_undo,
        onAction: () => versions.restore(before),
      );
      _leave();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final editor = _editor, file = _file;
    final labels = [
      (DkIcons.pan, l.edit_pan),
      (DkIcons.pen, l.edit_pen),
      (DkIcons.highlighter, l.edit_highlighter),
      (DkIcons.textBox, l.edit_text),
      (DkIcons.shape, l.edit_shapes),
      (DkIcons.note, l.edit_note),
      (DkIcons.tool('sign'), l.edit_sign),
      (DkIcons.eraser, l.edit_eraser),
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: ListenableBuilder(
        listenable: editor ?? const AlwaysStoppedAnimation(0),
        builder: (context, _) => Scaffold(
          backgroundColor: t.color.surfaceSunken,
          appBar: DkTopBar.editing(
            title: l.edit_title,
            onCancel: _cancel,
            onDone: editor != null && editor.dirty && !_saving ? _done : null,
          ),
          body: _missing
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(t.space.xl),
                    child: Text(
                      l.viewer_file_missing,
                      style: t.text.bodyM.copyWith(
                        color: t.color.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : editor == null || file == null
              ? const SizedBox.expand()
              : Column(
                  children: [
                    // Edit mode is on (§17.2).
                    Container(height: 2, color: t.color.primary),
                    Expanded(
                      child: DkPdfCanvas(
                        path: _view!,
                        panEnabled: editor.tool == EditTool.pan,
                        pageOverlay: (page, size) => AnnotationOverlay(
                          editor: editor,
                          page: page,
                          pageSize: size,
                          style: _style,
                        ),
                      ),
                    ),
                  ],
                ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: DkToolStrip(
              tools: [
                for (final (icon, label) in labels)
                  DkStripTool(icon: icon, label: label),
              ],
              selected: _selected,
              onSelect: _select,
              onUndo: editor != null && editor.canUndo ? editor.undo : null,
              onRedo: editor != null && editor.canRedo ? editor.redo : null,
            ),
          ),
        ),
      ),
    );
  }
}
