import 'dart:io';

import 'package:doc_core/doc_core.dart';
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
import '../../components/dk_segmented.dart';
import '../../components/dk_skeleton.dart';
import '../../components/dk_switch.dart';
import '../../components/dk_toast.dart';
import '../../components/dk_top_bar.dart';
import '../../errors/dokulo_error.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/formats.dart';
import '../../providers/file_providers.dart';
import '../../providers/job_providers.dart';
import '../../routes/bottom_chrome.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';
import '../../tools/tool_catalogue.dart';
import '../../tools/tool_definition.dart';
import '../v1_viewer/viewer_providers.dart';
import 'tool_options_providers.dart';

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
  var _starting = false;

  ToolDefinition get _def => widget.definition;

  Future<void> _run(ToolSubject subject, ToolValues values) async {
    final l = AppLocalizations.of(context);
    setState(() => _starting = true);
    try {
      final store = await ref.read(fileStoreProvider.future);
      final out = await store.workDirectory.createTemp('${_def.id}_');
      final queue = await ref.read(jobQueueProvider.future);
      final run = await queue.start(
        _def.id,
        _def.input!(subject, values, ToolEnv(outputDir: out.path, l10n: l)),
      );
      // The mini job bar shows it from here; X2's button and sheet come
      // with DK-0375, the failure state with DK-0377.
      await run.result;
      if (mounted) context.push(Routes.toolResult(_def.id));
    } catch (e) {
      if (mounted) showDkToast(context, DokuloError.from(e).title(l));
    } finally {
      if (mounted) setState(() => _starting = false);
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
          label: _def.action?.call(l, subject) ?? tool.name(l),
          caption: ready ? _def.estimate?.call(l, subject, values) : null,
          loading: _starting,
          onPressed: canRun && !_starting ? () => _run(subject, values) : null,
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
