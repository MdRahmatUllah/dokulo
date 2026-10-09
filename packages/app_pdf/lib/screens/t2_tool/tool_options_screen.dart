import 'dart:async';
import 'dart:io';

import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_action_bar.dart';
import '../../components/dk_action_sheet.dart';
import '../../components/dk_button.dart';
import '../../components/dk_file_card.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_icon_button.dart';
import '../../components/dk_menu.dart';
import '../../components/dk_option_row.dart';
import '../../components/dk_privacy_line.dart';
import '../../components/dk_progress_sheet.dart';
import '../../components/dk_segmented.dart';
import '../../components/dk_sheet.dart';
import '../../components/dk_skeleton.dart';
import '../../components/dk_switch.dart';
import '../../components/dk_text_field.dart';
import '../../components/dk_toast.dart';
import '../../components/dk_top_bar.dart';
import '../../errors/dokulo_error.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/formats.dart';
import '../../patterns/dk_confirmations.dart';
import '../../providers/file_providers.dart';
import '../../routes/bottom_chrome.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';
import '../../theme/dk_layout.dart';
import '../../tools/tool_catalogue.dart';
import '../../tools/tool_definition.dart';
import '../../tools/tool_inputs.dart';
import '../v1_viewer/viewer_providers.dart';
import 'tool_options_providers.dart';
import 'tool_run.dart';

/// T2, the tool options screen (UI spec §20.1; DK-0370): one shell for every
/// tool. Top bar (the tool's icon, name and Pro badge; overflow: Reset
/// options), the privacy line, the input files, the tool's declared options
/// (and "More options"), and the action bar with the estimate and the main
/// button. Options are kept per tool while the app runs.
class ToolOptionsScreen extends ConsumerStatefulWidget {
  const ToolOptionsScreen({
    super.key,
    required this.definition,
    required this.fileIds,
  });

  final ToolDefinition definition;

  /// The input files' row ids, in order.
  final List<int> fileIds;

  @override
  ConsumerState<ToolOptionsScreen> createState() => _ToolOptionsScreenState();
}

class _ToolOptionsScreenState extends ConsumerState<ToolOptionsScreen> {
  /// The input once the user changed it (picked, removed, reordered); until
  /// then the route's files, as they load.
  List<FileEntry>? _input;

  /// Passwords of unlocked inputs, by path: in memory, for this run only
  /// (DK-0372).
  final _passwords = <String, String>{};
  var _nextPickedId = -1;
  // The run (UI spec §20.2): its phase, the progress sheet's state, and
  // whether the sheet is open (its context, to close it).
  ToolRunHandle? _handle;
  var _phase = X2Phase.quiet;
  // Set once the job has run 30 s: cancelling then asks first (DK-0376).
  var _askBeforeCancel = false;
  final _sheet = ValueNotifier<_SheetState>(const _SheetState());
  BuildContext? _sheetContext;
  Timer? _toButton, _toSheet, _toAsk;
  StreamSubscription<JobProgress>? _progress;

  ToolDefinition get _def => widget.definition;

  @override
  void dispose() {
    _stopFollowing();
    _sheet.dispose();
    super.dispose();
  }

  void _stopFollowing() {
    _toButton?.cancel();
    _toSheet?.cancel();
    _toAsk?.cancel();
    _progress?.cancel();
  }

  void _setInput(List<FileEntry> files) => setState(() => _input = files);

  /// Adds [picked] to the input (a one-file tool: replaces it), skipping
  /// files already in it.
  void _add(List<FileEntry> current, List<FileEntry> picked, ToolInput input) {
    if (!input.many) return _setInput(picked.take(1).toList());
    final paths = {for (final f in current) f.path};
    _setInput([
      ...current,
      for (final f in picked)
        if (paths.add(f.path)) f,
    ]);
  }

  /// Browse device or Choose photos: copies into the sandbox first (the
  /// original stays untouched), then adds them (DK-0371).
  Future<void> _browse(
    List<FileEntry> current,
    ToolInput input, {
    required bool photos,
  }) async {
    final paths = await ref.read(devicePickerProvider)(input, photos: photos);
    if (paths.isEmpty) return;
    final store = await ref.read(fileStoreProvider.future);
    final picked = <FileEntry>[];
    for (final path in paths) {
      if (!input.takes(path)) continue;
      final copy = await store.importIncoming(File(path));
      final stat = await copy.stat();
      var pages = 0;
      if (ToolInput.kindOf(copy.path) == DkFileKind.pdf) {
        try {
          pages = (await PdfEngine.inspect(copy.path)).pageCount;
        } on DocError {
          // Locked or damaged: its row says so (DK-0372) or the run does.
        }
      }
      picked.add(
        FileEntry(
          id: _nextPickedId--,
          path: copy.path,
          name: copy.uri.pathSegments.last,
          size: stat.size,
          pages: pages,
          created: stat.changed,
          modified: stat.modified,
          hasText: false,
          encrypted: false,
        ),
      );
    }
    if (mounted && picked.isNotEmpty) _add(current, picked, input);
  }

  /// Starts the tool and follows it: nothing under 2 s, the button's
  /// loading state to 10 s, then the progress sheet (DK-0375). It ends in T3,
  /// a "Cancelled" toast (DK-0376) or the sheet's error state (DK-0377).
  Future<void> _run(ToolSubject subject, ToolValues values) async {
    final l = AppLocalizations.of(context);
    _sheet.value = const _SheetState();
    final ToolRunHandle run;
    try {
      run = await ref.read(toolRunnerProvider)(
        _def.id,
        (out) => _def.input!(subject, values, ToolEnv(outputDir: out, l10n: l)),
      );
    } catch (e) {
      // The preflight refused it (no space, too large, locked).
      if (mounted) _fail(subject, values, e);
      return;
    }
    if (!mounted) return run.cancel();
    setState(() {
      _handle = run;
      _phase = X2Phase.quiet;
    });
    final started = DateTime.now();
    _askBeforeCancel = false;
    _toAsk = Timer(confirmCancelAfter, () => _askBeforeCancel = true);
    _toButton = Timer(x2Button, () => setState(() => _phase = X2Phase.button));
    _toSheet = Timer(x2Sheet, () {
      setState(() => _phase = X2Phase.sheet);
      _openSheet(subject, values);
    });
    _progress = run.progress.listen((p) {
      final shown = _sheet.value.eta;
      _sheet.value = _sheet.value.copyWith(
        progress: p,
        eta: p.etaSeconds == null ? shown : smoothEta(shown, p.etaSeconds!),
      );
    });
    try {
      final output = await run.result;
      _end();
      if (!mounted) return;
      _closeSheet();
      if (output is JobOutput) {
        ref
            .read(lastToolResultProvider.notifier)
            .set(
              ToolResult(
                toolId: _def.id,
                inputs: subject.files,
                output: output,
                took: DateTime.now().difference(started),
              ),
            );
      }
      // T3 takes T2's place: its Close returns to where the tool started.
      context.pushReplacement(Routes.toolResult(_def.id));
    } catch (e) {
      _end();
      await run.discard();
      if (!mounted) return;
      final error = DokuloError.from(e);
      if (error.situation == DkErrorSituation.cancelled) {
        _closeSheet();
        showDkToast(context, error.title(l));
      } else {
        _fail(subject, values, e);
      }
    }
  }

  void _end() {
    _stopFollowing();
    if (mounted) {
      setState(() {
        _handle = null;
        _phase = X2Phase.quiet;
      });
    }
  }

  /// The sheet's error state, opening the sheet if it isn't (DK-0377).
  void _fail(ToolSubject subject, ToolValues values, Object e) {
    _sheet.value = _sheet.value.copyWith(error: DokuloError.from(e));
    if (_sheetContext == null) _openSheet(subject, values);
  }

  void _openSheet(ToolSubject subject, ToolValues values) {
    final l = AppLocalizations.of(context);
    final tool = ToolCatalogue.of(_def.id);
    showDkSheet<void>(
      context,
      body: Builder(
        builder: (sheetContext) {
          _sheetContext = sheetContext;
          return ValueListenableBuilder(
            valueListenable: _sheet,
            builder: (context, s, _) {
              final p = s.progress;
              final error = s.error;
              return DkProgressSheet(
                toolIcon: tool.icon,
                title: _def.busyTitle?.call(l, subject) ?? tool.name(l),
                progress: p?.fraction ?? 0,
                page: p?.pageIndex == null ? null : p!.pageIndex! + 1,
                pageCount: p?.pageCount,
                timeLeft: s.eta == null ? null : formatSeconds(s.eta!),
                onCancel: () => _cancel(sheetContext),
                onKeepWorking: _closeSheet,
                error: error == null || error.actions.isEmpty
                    ? null
                    : DkProgressError(
                        title: error.title(l),
                        body: l.t2_failed_body,
                        action: error.actions.first.label(l),
                        onAction: () =>
                            _recover(error.actions.first, subject, values),
                      ),
              );
            },
          );
        },
      ),
    ).whenComplete(() => _sheetContext = null);
  }

  void _closeSheet() {
    final sheet = _sheetContext;
    if (sheet != null && sheet.mounted) Navigator.of(sheet).pop();
    _sheetContext = null;
  }

  /// Cancel: asks first once the job has run 30 s (DK-0376).
  Future<void> _cancel(BuildContext sheetContext) async {
    final run = _handle;
    if (run == null) return;
    if (_askBeforeCancel) {
      final l = AppLocalizations.of(context);
      final stop = await confirmDk(
        sheetContext,
        DkConfirmation.cancelJob,
        title: _def.stopTitle?.call(l),
      );
      if (!stop) return;
    }
    run.cancel();
  }

  /// The error's recovery action (UI spec §26.3).
  void _recover(DkRecovery action, ToolSubject subject, ToolValues values) {
    _closeSheet();
    final files = [for (final f in subject.files) '${f.id}'];
    switch (action) {
      case DkRecovery.tryAgain:
        _run(subject, values);
      case DkRecovery.tryRepair:
        context.push(Routes.tool('repair', files: files));
      case DkRecovery.splitFirst:
        context.push(Routes.tool('split', files: files));
      case DkRecovery.openReadOnly:
        context.push(Routes.viewer(files.first));
      case DkRecovery.manageStorage:
        context.push(Routes.settings('storage'));
      case DkRecovery.download:
        context.push(Routes.models);
      // The password row is under the file (DK-0372); the rest need the
      // engine's or the report's support first.
      case DkRecovery.enterPassword:
      case DkRecovery.skipPage:
      case DkRecovery.sendReport:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final tool = ToolCatalogue.of(_def.id);
    final chosen = ref.watch(toolOptionValuesProvider(_def.id));
    final values = {..._def.initialValues, ...chosen};
    final input = ToolInput.of(_def.id) ?? const ToolInput({DkFileKind.pdf});
    final loaded = [
      for (final id in widget.fileIds) ref.watch(viewerFileProvider(id)),
    ];
    final ready = _input != null || loaded.every((f) => f is AsyncData);
    final files =
        _input ??
        [
          for (final f in loaded)
            if (f case AsyncData(:final value)) value,
        ];
    final locked = [
      for (final f in files)
        if (ref.watch(pdfLockedProvider(f.path)).value == true &&
            !_passwords.containsKey(f.path))
          f,
    ];
    final subject = ToolSubject(files, passwords: Map.of(_passwords));
    // Until the tool has enough files, the picker stays: for Merge and
    // Compare (two at least) with checkboxes.
    final choosing = ready && files.length < input.min;
    final canRun = ready && !choosing && locked.isEmpty && _def.input != null;
    final String? caption;
    if (!ready) {
      caption = null;
    } else if (choosing) {
      caption = l.t2_choose_to_continue;
    } else if (locked.isNotEmpty) {
      caption = l.t2_unlock_to_continue(locked.first.name);
    } else {
      caption = _def.estimate?.call(l, subject, values);
    }

    void set(String key, Object? value) =>
        ref.read(toolOptionValuesProvider(_def.id).notifier).set(key, value);

    return Scaffold(
      backgroundColor: t.color.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(DkTopBar.height),
        child: DkTopBar(
          title: tool.name(l),
          titleIcon: tool.icon,
          titlePro: tool.isPro,
          onOverflow: (anchor) => showDkMenu(
            anchor,
            groups: [
              [
                DkAction(
                  icon: DkIcons.undo,
                  label: l.t2_reset_options,
                  onTap: ref
                      .read(toolOptionValuesProvider(_def.id).notifier)
                      .reset,
                ),
              ],
            ],
          ),
        ),
      ),
      // File cards bring their own 16 inset; the rest gets it here.
      body: ListView(
        padding: EdgeInsets.only(top: t.space.xs),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.l),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: DkPrivacyLine(),
            ),
          ),
          if (choosing)
            _PickerCard(
              toolId: _def.id,
              input: input,
              selected: files,
              onToggle: (f) => files.any((x) => x.path == f.path)
                  ? _setInput([
                      for (final x in files)
                        if (x.path != f.path) x,
                    ])
                  : _add(files, [f], input),
              onBrowse: () => _browse(files, input, photos: false),
              onPhotos: input.images
                  ? () => _browse(files, input, photos: true)
                  : null,
            )
          else ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space.l),
              child: Row(
                children: [
                  Expanded(
                    child: _Header(
                      files.length == 1
                          ? l.t2_section_file
                          : l.t2_section_files(files.length),
                    ),
                  ),
                  if (input.many && ready)
                    Padding(
                      padding: EdgeInsets.only(top: t.space.l),
                      child: DkButton(
                        label: l.common_add_files,
                        icon: DkIcons.add,
                        variant: DkButtonVariant.tertiary,
                        size: DkButtonSize.compact,
                        onPressed: () => _browse(files, input, photos: false),
                      ),
                    ),
                ],
              ),
            ),
            if (!ready)
              DkSkeleton.fileRows(count: widget.fileIds.length.clamp(1, 4))
            else if (files.length == 1)
              _InputFile(
                file: files.single,
                locked: locked.contains(files.single),
                onUnlock: (pw) =>
                    setState(() => _passwords[files.single.path] = pw),
              )
            else
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (from, to) {
                  final order = [...files];
                  order.insert(to, order.removeAt(from));
                  _setInput(order);
                },
                children: [
                  for (final (i, f) in files.indexed)
                    _InputFile(
                      key: ValueKey(f.path),
                      file: f,
                      index: i,
                      locked: locked.contains(f),
                      onUnlock: (pw) => setState(() => _passwords[f.path] = pw),
                      onRemove: () => _setInput([
                        for (final x in files)
                          if (x.path != f.path) x,
                      ]),
                    ),
                ],
              ),
          ],
          if (_def.options.isNotEmpty || _def.moreOptions.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(l.t2_section_options),
                  for (final (i, o) in _def.options.indexed)
                    _OptionRow(
                      option: o,
                      subject: subject,
                      value: values[o.key],
                      onChanged: (v) => set(o.key, v),
                      last:
                          i == _def.options.length - 1 &&
                          _def.moreOptions.isEmpty,
                    ),
                  if (_def.moreOptions.isNotEmpty)
                    DkMoreOptions(
                      children: [
                        for (final (i, o) in _def.moreOptions.indexed)
                          _OptionRow(
                            option: o,
                            subject: subject,
                            value: values[o.key],
                            onChanged: (v) => set(o.key, v),
                            last: i == _def.moreOptions.length - 1,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          SizedBox(height: t.space.xl),
        ],
      ),
      // The main action is the last thing a screen reader reaches.
      bottomNavigationBar: DkBottomChrome(
        child: DkActionBar(
          label: _phase == X2Phase.quiet
              ? _def.action?.call(l, subject) ?? tool.name(l)
              : _def.busyLabel?.call(l) ?? l.t2_busy,
          caption: caption,
          // Under 2 s only the press shows; then "Compressing…" (§20.2).
          loading: _phase != X2Phase.quiet,
          onPressed: canRun
              ? () {
                  if (_handle == null) _run(subject, values);
                }
              : null,
        ),
      ),
    );
  }
}

/// A section header in `type.titleS`, a heading for screen readers.
class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(top: t.space.xl, bottom: t.space.s),
      // Its own node: merged into the section, it would lose the flag.
      child: Semantics(
        container: true,
        header: true,
        child: Text(
          text,
          style: t.text.titleS.copyWith(color: t.color.textPrimary),
        ),
      ),
    );
  }
}

/// One input file as a DkFileCard row; in a multi-file tool with × to remove
/// it and a drag handle to reorder (UI spec §20.1 region 3).
class _InputFile extends ConsumerWidget {
  const _InputFile({
    super.key,
    required this.file,
    required this.locked,
    required this.onUnlock,
    this.index,
    this.onRemove,
  });

  final FileEntry file;

  /// It needs a password (DK-0372): the unlock row shows under it.
  final bool locked;
  final ValueChanged<String> onUnlock;

  /// Its place in a reorderable list; null for a single file.
  final int? index;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final image = _isImage(file.name);
    final thumb = image
        ? null
        : ref.watch(pdfThumbnailProvider(file.path)).value;
    final card = DkFileCard(
      name: file.name,
      meta: [
        formatBytes(file.size, locale),
        if (!image && file.pages > 0) l.meta_pages(file.pages),
      ].join(' · '),
      kind: image ? DkFileKind.image : DkFileKind.pdf,
      thumbnail: image
          ? Image.file(File(file.path), fit: BoxFit.cover)
          : thumb == null
          ? null
          : RawImage(image: thumb),
      encrypted: file.encrypted || locked,
      // A picked file isn't in the index (negative id): nothing to open.
      onTap: file.id < 0
          ? () {}
          : () => context.push(Routes.viewer('${file.id}')),
    );
    final unlock = locked ? _UnlockRow(file: file, onUnlock: onUnlock) : null;
    if (index == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [card, ?unlock],
      );
    }
    final row = Row(
      children: [
        Expanded(child: card),
        DkIconButton(
          icon: DkIcons.close,
          tooltip: '${l.t2_remove_file} ${file.name}',
          onPressed: onRemove,
        ),
        ReorderableDragStartListener(
          index: index!,
          child: Padding(
            padding: EdgeInsets.all(t.space.s),
            child: DkIcon(DkIcons.dragHandle, color: t.color.iconSecondary),
          ),
        ),
      ],
    );
    if (unlock == null) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [row, unlock],
    );
  }

  static bool _isImage(String name) =>
      RegExp(r'\.(jpe?g|png|heic|webp)$', caseSensitive: false).hasMatch(name);
}

/// A declared option as its DkOptionRow.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.subject,
    required this.value,
    required this.onChanged,
    required this.last,
  });

  final ToolOption option;
  final ToolSubject subject;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final help = option.help?.call(l);
    return switch (option) {
      ToolSwitch() => DkOptionRow(
        title: option.title(l),
        help: help,
        last: last,
        control: DkSwitch(value: value! as bool, onChanged: onChanged),
      ),
      final ToolSegments<Object> o => DkOptionRow(
        title: option.title(l),
        help: help,
        last: last,
        controlBelow: true,
        control: DkSegmented<Object>(
          segments: o.segments(l),
          selected: value!,
          onChanged: onChanged,
        ),
      ),
      ToolCustom(:final builder) => DkOptionRow(
        title: option.title(l),
        help: help,
        last: last,
        controlBelow: true,
        control: builder(context, subject, value, onChanged),
      ),
    };
  }
}

/// What the progress sheet shows: the latest progress, the smoothed time
/// left, and an error once the job failed.
class _SheetState {
  const _SheetState({this.progress, this.eta, this.error});

  final JobProgress? progress;
  final int? eta;
  final DokuloError? error;

  _SheetState copyWith({JobProgress? progress, int? eta, DokuloError? error}) =>
      _SheetState(
        progress: progress ?? this.progress,
        eta: eta ?? this.eta,
        error: error ?? this.error,
      );
}

/// "This file is locked" with the password and Unlock, under a locked input
/// (DK-0372). The password is checked by opening the file; it stays in
/// memory for this run only.
class _UnlockRow extends StatefulWidget {
  const _UnlockRow({required this.file, required this.onUnlock});

  final FileEntry file;
  final ValueChanged<String> onUnlock;

  @override
  State<_UnlockRow> createState() => _UnlockRowState();
}

class _UnlockRowState extends State<_UnlockRow> {
  final _password = TextEditingController();
  var _wrong = false;
  var _checking = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final password = _password.text;
    if (password.isEmpty) return;
    setState(() => _checking = true);
    try {
      await PdfEngine.inspect(widget.file.path, password: password);
      widget.onUnlock(password);
    } on DocError {
      if (mounted) setState(() => _wrong = true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(t.space.l, 0, t.space.l, t.space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: t.space.s,
        children: [
          Row(
            spacing: t.space.xs,
            children: [
              DkIcon(DkIcons.lock, size: DkIconSize.s, color: t.color.warning),
              Text(
                l.t2_file_locked,
                style: t.text.labelM.copyWith(color: t.color.textPrimary),
              ),
            ],
          ),
          DkPasswordField(
            label: l.t2_password,
            controller: _password,
            error: _wrong ? l.t2_wrong_password : null,
            onChanged: (_) {
              if (_wrong) setState(() => _wrong = false);
            },
            onSubmitted: (_) => _unlock(),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: DkButton(
              label: l.t2_unlock,
              variant: DkButtonVariant.secondary,
              size: DkButtonSize.compact,
              loading: _checking,
              onPressed: _checking ? null : _unlock,
            ),
          ),
        ],
      ),
    );
  }
}

/// T2 without input (DK-0371): "Choose a PDF" / "Choose images" / "Choose
/// files", the 5 most recent files the tool takes, Browse device and, for
/// image tools, Choose photos. A tool that needs two files or more shows
/// checkboxes; the others take the file tapped.
class _PickerCard extends ConsumerWidget {
  const _PickerCard({
    required this.toolId,
    required this.input,
    required this.selected,
    required this.onToggle,
    required this.onBrowse,
    required this.onPhotos,
  });

  final String toolId;
  final ToolInput input;
  final List<FileEntry> selected;
  final ValueChanged<FileEntry> onToggle;
  final VoidCallback onBrowse;
  final VoidCallback? onPhotos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final checkboxes = input.min > 1;
    final recent = ref.watch(recentCompatibleFilesProvider(toolId)).value;
    final paths = {for (final f in selected) f.path};
    // Picked from the device, they show too, checked.
    final rows = [
      ...?recent,
      for (final f in selected)
        if (!(recent ?? const []).any((r) => r.path == f.path)) f,
    ];
    final title = input.kinds.length > 1
        ? l.t2_choose_files
        : input.images
        ? l.t2_choose_images
        : l.t2_choose_pdf;
    return Container(
      margin: EdgeInsets.fromLTRB(t.space.l, t.space.l, t.space.l, 0),
      padding: EdgeInsets.symmetric(vertical: t.space.m),
      decoration: t.surfaceAt(
        DkLevel.raised,
        radius: BorderRadius.circular(t.radius.m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.l),
            child: Semantics(
              container: true,
              header: true,
              child: Text(
                title,
                style: t.text.titleS.copyWith(color: t.color.textPrimary),
              ),
            ),
          ),
          if (rows.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(t.space.l, t.space.m, t.space.l, 0),
              child: Text(
                l.t2_recent,
                style: t.text.labelM.copyWith(color: t.color.textSecondary),
              ),
            ),
          for (final f in rows)
            DkFileCard(
              name: f.name,
              meta: [
                formatBytes(f.size, locale),
                if (f.pages > 0) l.meta_pages(f.pages),
              ].join(' · '),
              kind: ToolInput.kindOf(f.name) ?? DkFileKind.pdf,
              selected: checkboxes ? paths.contains(f.path) : null,
              onTap: () => onToggle(f),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(t.space.l, t.space.s, t.space.l, 0),
            child: Wrap(
              spacing: t.space.s,
              runSpacing: t.space.s,
              children: [
                DkButton(
                  label: l.common_browse,
                  icon: DkIcons.folderOpen,
                  variant: DkButtonVariant.secondary,
                  onPressed: onBrowse,
                ),
                if (onPhotos != null)
                  DkButton(
                    label: l.t2_choose_photos,
                    icon: DkIcons.importPhotos,
                    variant: DkButtonVariant.secondary,
                    onPressed: onPhotos,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
