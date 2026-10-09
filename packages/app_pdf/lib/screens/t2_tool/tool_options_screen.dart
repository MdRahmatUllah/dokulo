import 'dart:async';
import 'dart:io';

import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_action_bar.dart';
import '../../components/dk_action_sheet.dart';
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
import '../../components/dk_toast.dart';
import '../../components/dk_top_bar.dart';
import '../../errors/dokulo_error.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/formats.dart';
import '../../patterns/dk_confirmations.dart';
import '../../routes/bottom_chrome.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';
import '../../tools/tool_catalogue.dart';
import '../../tools/tool_definition.dart';
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
  late List<int> _ids = widget.fileIds;
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
      await run.result;
      _end();
      if (!mounted) return;
      _closeSheet();
      context.push(Routes.toolResult(_def.id));
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
    final loaded = [for (final id in _ids) ref.watch(viewerFileProvider(id))];
    final files = [
      for (final f in loaded)
        if (f case AsyncData(:final value)) value,
    ];
    final ready = files.length == _ids.length;
    final subject = ToolSubject(files);

    void set(String key, Object? value) =>
        ref.read(toolOptionValuesProvider(_def.id).notifier).set(key, value);

    final canRun = ready && files.isNotEmpty && _def.input != null;
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
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.l),
            child: _Header(
              _ids.length == 1
                  ? l.t2_section_file
                  : l.t2_section_files(_ids.length),
            ),
          ),
          if (!ready)
            DkSkeleton.fileRows(count: _ids.length.clamp(1, 4))
          else if (_ids.length == 1)
            _InputFile(file: files.single)
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (from, to) => setState(() {
                final ids = [..._ids];
                ids.insert(to, ids.removeAt(from));
                _ids = ids;
              }),
              children: [
                for (final (i, f) in files.indexed)
                  _InputFile(
                    key: ValueKey(f.id),
                    file: f,
                    index: i,
                    onRemove: () =>
                        setState(() => _ids = [..._ids]..remove(f.id)),
                  ),
              ],
            ),
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
          caption: ready ? _def.estimate?.call(l, subject, values) : null,
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
  const _InputFile({super.key, required this.file, this.index, this.onRemove});

  final FileEntry file;

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
      encrypted: file.encrypted,
      onTap: () => context.push(Routes.viewer('${file.id}')),
    );
    if (index == null) return card;
    return Row(
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
