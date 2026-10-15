import 'dart:io';
import 'dart:ui' as ui;

import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdfrx/pdfrx.dart' show PdfViewerController;

import '../../components/dk_editor_bars.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_button.dart';
import '../../components/dk_pdf_canvas.dart';
import '../../components/dk_settings_row.dart';
import '../../components/dk_sheet.dart';
import '../../components/dk_text_field.dart';
import '../../components/dk_tool_options_sheet.dart';
import '../../components/dk_toast.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../patterns/dk_confirmations.dart';
import '../../patterns/dk_form_accessory.dart';
import '../../providers/file_providers.dart';
import '../../providers/files_providers.dart';
import '../../providers/prefs_providers.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';
import '../sign/signatures_sheet.dart';
import '../v1_viewer/viewer_providers.dart';
import 'annotation_editor.dart';
import 'annotation_overlay.dart';
import 'form_layer.dart';

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

/// The tools with an options sheet, and which (DK-0315..DK-0320). Pan has
/// none.
const _toolKinds = {
  EditTool.pen: DkMarkupKind.pen,
  EditTool.highlighter: DkMarkupKind.highlighter,
  EditTool.text: DkMarkupKind.text,
  EditTool.shapes: DkMarkupKind.shape,
  EditTool.note: DkMarkupKind.note,
  EditTool.eraser: DkMarkupKind.eraser,
};

/// Where the tools' last-used options are kept.
const _prefsKey = 'edit.options';

List<(IconData, String)> _labels(AppLocalizations l) => [
  (DkIcons.pan, l.edit_pan),
  (DkIcons.pen, l.edit_pen),
  (DkIcons.highlighter, l.edit_highlighter),
  (DkIcons.textBox, l.edit_text),
  (DkIcons.shape, l.edit_shapes),
  (DkIcons.note, l.edit_note),
  (DkIcons.tool('sign'), l.edit_sign),
  (DkIcons.eraser, l.edit_eraser),
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
/// leaves. Reading mode (V1) never creates marks. A second tap on the
/// selected tool opens its options, remembered across launches; a placed
/// text box or note asks for its text. [fromSign]: entered from
/// Sign, so Pan is selected and the signatures sheet opens.
class EditScreen extends ConsumerStatefulWidget {
  const EditScreen({
    super.key,
    required this.fileId,
    this.fromSign = false,
    this.startTool,
  });

  /// Selected when the file is open (Mark up: the highlighter, DK-0517).
  final EditTool? startTool;

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

  /// The file couldn't be read: locked (true) or damaged (false).
  bool? _problem;

  /// Each tool's options, last used first (kept in [prefsProvider]).
  late final Map<EditTool, DkToolOptions> _options = {
    for (final tool in _toolKinds.keys) tool: _loadOptions(tool),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _editor?.dispose();
    _formText.dispose();
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
    // The tools' last-used options, before the strip is used.
    await ref.read(prefsProvider.future);
    final PdfInfo info;
    final Map<int, List<PageAnnot>> read;
    try {
      info = _info = await PdfEngine.inspect(file.path);
      read = {
        for (var p = 0; p < info.pageCount; p++)
          p: await PdfAnnotations.read(file.path, p),
      };
      // An AcroForm's fields, in the file's order (DK-0324).
      if (await PdfForms.kind(file.path) == PdfFormKind.acroForm) {
        _fields = await PdfForms.fields(file.path);
      }
    } on DocError catch (e) {
      // ponytail: locked files open in V1 (unlock there first); edit mode
      // says why it can't, instead of spinning.
      if (mounted) {
        setState(() => _problem = e.kind == DocErrorKind.locked);
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _file = file;
      _view = view.path;
      _editor = AnnotationEditor(read: read)..tool = EditTool.pan;
    });
    if (widget.fromSign) await _sign();
    if (widget.startTool case final tool?) {
      final index = _strip.indexOf(tool);
      if (index >= 0) _select(index);
    }
  }

  void _select(int index) {
    final tool = _strip[index];
    if (tool == null) {
      _sign();
      return;
    }
    // A second tap on the selected tool: its options (DK-0314..DK-0320).
    if (index == _selected && _toolKinds.containsKey(tool)) {
      _openOptions(tool, index);
      return;
    }
    setState(() => _selected = index);
    _editor!.tool = tool;
  }

  DkToolOptions _loadOptions(EditTool tool) {
    final saved = ref.read(prefsProvider).value?['$_prefsKey.${tool.name}'];
    final base = _defaults(tool);
    if (saved is! Map) return base;
    // Kept by an older version or edited by hand: anything of the wrong
    // type or out of range falls back to the default.
    double? number(Object? v, double min, double max) =>
        v is num ? v.toDouble().clamp(min, max) : null;
    return base.copyWith(
      color: saved['color'] is int ? Color(saved['color'] as int) : null,
      thickness: number(saved['thickness'], 1, tool == EditTool.pen ? 8 : 12),
      opacity: number(saved['opacity'], 0.3, 0.6),
      fontSize: number(saved['fontSize'], 8, 24)?.round(),
      shape: DkShapeKind.values.asNameMap()[saved['shape']],
      eraser: DkEraserMode.values.asNameMap()[saved['eraser']],
    );
  }

  DkToolOptions _defaults(EditTool tool) {
    final m = context.tokens.markup;
    return switch (tool) {
      // The designs' defaults: pen 3 pt, text 12 pt, shapes 2 pt in red.
      EditTool.highlighter => DkToolOptions(color: m.yellow),
      EditTool.shapes => DkToolOptions(color: m.red, thickness: 2),
      EditTool.note => DkToolOptions(color: m.yellow),
      EditTool.text => DkToolOptions(color: m.black, fontSize: 12),
      _ => DkToolOptions(color: m.black),
    };
  }

  Future<void> _openOptions(EditTool tool, int index) async {
    final l = AppLocalizations.of(context);
    final before = _options[tool]!;
    await showDkSheet<void>(
      context,
      title: _labels(l)[index].$2,
      showClose: true,
      body: StatefulBuilder(
        builder: (context, setSheet) => DkToolOptionsSheet(
          kind: _toolKinds[tool]!,
          options: _options[tool]!,
          onChanged: (o) {
            setSheet(() {});
            setState(() => _options[tool] = o);
          },
        ),
      ),
    );
    // Remembered once the sheet closes: one write, not one per slider step.
    final o = _options[tool]!;
    if (!mounted || identical(o, before)) return;
    await ref.read(prefsProvider.notifier).set('$_prefsKey.${tool.name}', {
      'color': o.color.toARGB32(),
      'thickness': o.thickness,
      'opacity': o.opacity,
      'fontSize': o.fontSize,
      'shape': o.shape.name,
      'eraser': o.eraser.name,
    });
  }

  /// The overlay's style from the tools' options.
  EditStyle get _style {
    final pen = _options[EditTool.pen]!,
        hi = _options[EditTool.highlighter]!,
        text = _options[EditTool.text]!,
        shapes = _options[EditTool.shapes]!;
    return EditStyle(
      penColor: pen.color.toARGB32(),
      penWidth: pen.thickness,
      highlighterColor: hi.color.withValues(alpha: hi.opacity).toARGB32(),
      shape: shapes.shape,
      shapeColor: shapes.color.toARGB32(),
      shapeWidth: shapes.thickness,
      textColor: text.color.toARGB32(),
      fontSize: text.fontSize.toDouble(),
      noteColor: _options[EditTool.note]!.color.toARGB32(),
      eraseObjects: _options[EditTool.eraser]!.eraser == DkEraserMode.object,
    );
  }

  /// A text box or a note was placed: type its text (DK-0317, DK-0319).
  Future<void> _placed(AnnotRef ref) async {
    final editor = _editor!;
    final annot = [
      for (final a in editor.annotsOn(ref.page))
        if (a.id == ref.id) a.annot,
    ].firstOrNull;
    final l = AppLocalizations.of(context);
    final note = annot is NoteAnnot;
    if (annot is! FreeTextAnnot && !note) return;
    final before = annot is FreeTextAnnot ? annot.text : annot!.note;
    // Just placed (still empty): the box and its text are one Undo step,
    // and a box left empty goes again.
    final placed = before.isEmpty;
    final text = await showDkSheet<String>(
      context,
      title: note ? l.edit_note : l.edit_text,
      showClose: true,
      body: _TextSheet(
        text: before,
        label: note ? l.edit_note : l.edit_text,
        done: l.common_done,
      ),
    );
    if (!mounted) return;
    if (placed && (text == null || text.trim().isEmpty)) {
      editor.retract();
      return;
    }
    if (text == null || text == before) return;
    (placed ? editor.amend : editor.update)(
      ref,
      (a) => switch (a) {
        FreeTextAnnot(:final rect, :final fontSize, :final color) =>
          FreeTextAnnot(rect, text, fontSize: fontSize, color: color),
        NoteAnnot(:final at, :final color) => NoteAnnot(
          at,
          note: text,
          color: color,
        ),
        _ => a,
      },
    );
  }

  /// Sign: Pan, and the signatures sheet; the chosen signature lands
  /// centred on the page in view at 40 % of its width, selected, with the
  /// date beside it when "Add date" is on (UI spec §17.3; DK-0328).
  Future<void> _sign() async {
    setState(() => _selected = 0);
    _editor!.tool = EditTool.pan;
    final picked = await showSignaturesSheet(context);
    if (picked == null || !mounted) return;
    final (_, png) = picked;
    final info = _info;
    if (info == null) return;
    final descriptor = await ui.ImageDescriptor.encoded(
      await ui.ImmutableBuffer.fromUint8List(png),
    );
    final size = (width: descriptor.width, height: descriptor.height);
    descriptor.dispose();
    if (!mounted || size.width == 0) return;
    final page = ((_canvas.isReady ? _canvas.pageNumber : null) ?? 1) - 1;
    final p = info.pages[page.clamp(0, info.pageCount - 1)];
    final w = p.width * 0.4, h = w * size.height / size.width;
    final addDate = ref.read(prefsProvider).value?[signAddDateKey] == true;
    _editor!.add(
      page,
      StampAnnot(
        (
          left: (p.width - w) / 2,
          top: (p.height + h) / 2,
          right: (p.width + w) / 2,
          bottom: (p.height - h) / 2,
        ),
        png,
        date: addDate
            ? DateFormat.yMd(AppLocalizations.of(context).localeName)
                  .format(DateTime.now())
            : null,
      ),
    );
  }

  // --- The form (DK-0324).

  List<PdfFormField> _fields = const [];
  final _formValues = <String, PdfFieldValue>{};
  String? _activeField;
  final _formText = TextEditingController();

  /// "Highlight fields": every fillable field tinted. ponytail: always on
  /// until the Fill form tool's overflow toggle (DK-0518).
  final _highlightFields = true;

  bool get _dirty => (_editor?.dirty ?? false) || _formValues.isNotEmpty;

  PdfFormField? get _activeText => switch (_activeField) {
    final id? =>
      _fields
          .where((f) => f.id == id && f.kind == PdfFieldKind.text)
          .firstOrNull,
    null => null,
  };

  /// The text being typed becomes the field's value once it changed.
  void _commitText() {
    final f = _activeText;
    if (f == null) return;
    final now = _formText.text;
    final before = fieldState(f, _formValues[f.id]).text;
    if (now != before) _formValues[f.id] = TextFieldValue(now);
  }

  /// The fields a user fills, in the file's order (its tab order).
  List<PdfFormField> get _fillable => [
    for (final f in _fields)
      if (!f.readOnly &&
          const {
            PdfFieldKind.text,
            PdfFieldKind.checkbox,
            PdfFieldKind.radio,
            PdfFieldKind.combo,
            PdfFieldKind.list,
          }.contains(f.kind))
        f,
  ];

  /// Previous / Next field: to the next text field in the file's order,
  /// scrolling to its page.
  void _moveField(int by) {
    final texts = [
      for (final f in _fillable)
        if (f.kind == PdfFieldKind.text) f,
    ];
    final i = texts.indexWhere((f) => f.id == _activeField);
    final next = i + by;
    if (i < 0 || next < 0 || next >= texts.length) return;
    final f = texts[next];
    if ((_canvas.isReady ? _canvas.pageNumber : null) != f.page + 1) {
      _canvas.goToPage(pageNumber: f.page + 1);
    }
    _tapField(f);
  }

  Future<void> _tapField(PdfFormField f) async {
    setState(() {
      _commitText();
      _activeField = null;
    });
    final now = fieldState(f, _formValues[f.id]);
    switch (f.kind) {
      case PdfFieldKind.text:
        _formText.text = now.text;
        setState(() => _activeField = f.id);
      case PdfFieldKind.checkbox:
        setState(() => _formValues[f.id] = CheckFieldValue(!now.checked));
      case PdfFieldKind.radio:
        // One of the group: the others of this name go off.
        setState(() {
          for (final other in _fields) {
            if (other.name == f.name) _formValues.remove(other.id);
          }
          _formValues[f.id] = const CheckFieldValue(true);
          for (final other in _fields) {
            if (other.name == f.name && other.id != f.id && other.checked) {
              _formValues[other.id] = const CheckFieldValue(false);
            }
          }
        });
      case PdfFieldKind.combo || PdfFieldKind.list:
        setState(() => _activeField = f.id);
        final picked = await showDkSheet<int>(
          context,
          title: f.name,
          showClose: true,
          body: Builder(
            builder: (sheet) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, o) in f.options.indexed)
                  DkSettingsRow(
                    title: o,
                    trailing: i == now.choice
                        ? DkIcon(
                            DkIcons.check,
                            color: context.tokens.color.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(sheet).pop(i),
                  ),
              ],
            ),
          ),
        );
        if (!mounted) return;
        setState(() {
          _activeField = null;
          if (picked != null && picked != now.choice) {
            _formValues[f.id] = ChoiceFieldValue(picked);
          }
        });
      case PdfFieldKind.signature ||
          PdfFieldKind.button ||
          PdfFieldKind.unknown:
        break;
    }
  }

  /// The file's pages (their sizes), read when it opened.
  PdfInfo? _info;
  final _canvas = PdfViewerController();

  Future<void> _cancel() async {
    if (_dirty) {
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
      _commitText();
      var result = out;
      if (_formValues.isNotEmpty) {
        // The filled form on top of the marks, regenerated as Acrobat does.
        result = await store.newTempFile(out.path.split(RegExp(r'[\\/]')).last);
        await PdfForms.fill(out.path, result.path, _formValues);
      }
      final versions = await ref.read(versionStoreProvider.future);
      final before = await versions.replace(widget.fileId, result.path);
      if (!mounted) return;
      // Signed: "Signed on page 3 · Undo" (DK-0519); else "Saved".
      final signed = editor.signedPage;
      showDkToast(
        context,
        signed == null ? l.toast_saved : l.sign_toast_signed(signed + 1),
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
    final labels = _labels(l);
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
            onDone: editor != null && _dirty && !_saving ? _done : null,
          ),
          body: _missing || _problem != null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(t.space.xl),
                    child: Text(
                      switch (_problem) {
                        true => l.viewer_locked_title,
                        false => l.viewer_damaged_body,
                        null => l.viewer_file_missing,
                      },
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
                        controller: _canvas,
                        panEnabled: editor.tool == EditTool.pan,
                        pageOverlay: (page, size) => Stack(
                          children: [
                            Positioned.fill(
                              child: AnnotationOverlay(
                                editor: editor,
                                page: page,
                                pageSize: size,
                                style: _style,
                                onPlaced: _placed,
                              ),
                            ),
                            // The fields answer while panning; the drawing
                            // tools draw over them.
                            if (editor.tool == EditTool.pan &&
                                _fields.any((f) => f.page == page))
                              Positioned.fill(
                                child: FormLayer(
                                  fields: [
                                    for (final f in _fields)
                                      if (f.page == page) f,
                                  ],
                                  pageSize: size,
                                  values: _formValues,
                                  active: _activeField,
                                  text: _formText,
                                  highlight: _highlightFields,
                                  onTap: _tapField,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Previous · Next field · Done over the keyboard.
                    if (_activeText != null &&
                        View.of(context).viewInsets.bottom > 0)
                      DkFormAccessoryBar(
                        onPrevious: () => _moveField(-1),
                        onNext: () => _moveField(1),
                        onDone: () => setState(() {
                          _commitText();
                          _activeField = null;
                        }),
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

/// A text box's or a note's text: a field and Done. It owns its controller,
/// so the sheet can animate away after Done.
class _TextSheet extends StatefulWidget {
  const _TextSheet({
    required this.text,
    required this.label,
    required this.done,
  });
  final String text, label, done;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final _field = TextEditingController(text: widget.text);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: context.tokens.space.l,
    children: [
      DkTextField(controller: _field, autofocus: true, hint: widget.label),
      DkButton(
        label: widget.done,
        expand: true,
        onPressed: () => Navigator.of(context).pop(_field.text),
      ),
    ],
  );
}
