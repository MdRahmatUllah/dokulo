import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/dk_file_card.dart';
import '../components/dk_icon.dart';
import '../components/dk_icon_button.dart';
import '../components/dk_sheet.dart';
import '../components/dk_tappable.dart';
import '../components/dk_text_field.dart';
import '../components/dk_tool_tile.dart';
import '../l10n/app_localizations.dart';
import '../l10n/formats.dart';
import '../providers/files_providers.dart';
import '../routes/routes.dart';
import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';
import '../tools/tool_catalogue.dart';
import '../tools/tool_inputs.dart';
import '../tools/tool_search.dart';

/// X1, the tool picker (UI spec §20.6; DK-1094): what to do with [files]
/// (the share sheet, "Open with", the viewer's Tools). A large sheet: the
/// file (or "4 files"), "Search tools", Open in viewer for one PDF, then
/// Suggested (the user's pinned tools that fit) and All tools, only the
/// ones that take these files: a list on phones, 4 columns on tablets. A
/// tool opens T2 with the files already chosen.
Future<void> showToolPicker(BuildContext context, List<FileEntry> files) =>
    showDkSheet<void>(
      context,
      detent: DkSheetDetent.large,
      body: _ToolPicker(files: files),
    );

/// The tools that take [files] (kind and count), Scan and Workflows aside.
List<ToolInfo> compatibleTools(List<FileEntry> files) => [
  for (final tool in ToolCatalogue.all)
    if (ToolInput.of(tool.id) case final input?
        when files.length >= input.min &&
            files.length <= input.max &&
            files.every((f) => input.takes(f.path)))
      tool,
];

class _ToolPicker extends ConsumerStatefulWidget {
  const _ToolPicker({required this.files});

  final List<FileEntry> files;

  @override
  ConsumerState<_ToolPicker> createState() => _ToolPickerState();
}

class _ToolPickerState extends ConsumerState<_ToolPicker> {
  var _query = '';

  void _open(String toolId) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(
      Routes.tool(toolId, files: [for (final f in widget.files) '${f.id}']),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final files = widget.files;
    final fits = compatibleTools(files);
    final shown = _query.trim().isEmpty
        ? fits
        : [
            for (final tool in searchTools(_query, l))
              if (fits.contains(tool)) tool,
          ];
    final pinned = ref.watch(pinnedToolsProvider).value ?? defaultPinnedTools;
    final suggested = _query.trim().isNotEmpty
        ? const <ToolInfo>[]
        : [for (final id in pinned) ?shown.where((s) => s.id == id).firstOrNull]
              .take(4)
              .toList();
    final rest = [
      for (final tool in shown)
        if (!suggested.contains(tool)) tool,
    ];
    final single = files.length == 1;
    final onePdf =
        single && ToolInput.kindOf(files.single.path) == DkFileKind.pdf;
    final tablet =
        DkGrid.forWidth(MediaQuery.sizeOf(context).width) != DkGrid.phone;

    Widget tools(List<ToolInfo> list) => tablet
        ? GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.1,
            children: [
              for (final tool in list)
                DkToolTile(toolId: tool.id, onTap: () => _open(tool.id)),
            ],
          )
        : Column(
            children: [
              for (final tool in list)
                DkToolRow(
                  toolId: tool.id,
                  inset: 0,
                  onTap: () => _open(tool.id),
                ),
            ],
          );

    Widget header(String text) => Padding(
      padding: EdgeInsets.only(top: t.space.l, bottom: t.space.xs),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: t.text.labelM.copyWith(color: t.color.textSecondary),
        ),
      ),
    );

    final locale = Localizations.localeOf(context).toLanguageTag();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: t.space.m,
          children: [
            _Thumb(path: files.first.path),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    single
                        ? files.single.name
                        : l.t2_section_files(files.length),
                    style: t.text.titleS.copyWith(color: t.color.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (single)
                    Text(
                      [
                        formatBytes(files.single.size, locale),
                        if (files.single.pages > 0)
                          l.meta_pages(files.single.pages),
                      ].join(' · '),
                      style: t.text.caption.copyWith(
                        color: t.color.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            DkIconButton(
              icon: DkIcons.close,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        SizedBox(height: t.space.m),
        DkTextField(
          hint: l.tools_search_hint,
          leading: DkIcon(DkIcons.search, color: t.color.iconSecondary),
          onChanged: (q) => setState(() => _query = q),
        ),
        if (onePdf && _query.trim().isEmpty)
          Padding(
            padding: EdgeInsets.only(top: t.space.s),
            child: _OpenInViewer(
              onTap: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.push(Routes.viewer('${files.single.id}'));
              },
            ),
          ),
        if (suggested.isNotEmpty) ...[header(l.x1_suggested), tools(suggested)],
        if (rest.isNotEmpty) ...[header(l.x1_all_tools), tools(rest)],
      ],
    );
  }
}

/// The file's first page, 44 × 56 (the share's first file for several).
class _Thumb extends ConsumerWidget {
  const _Thumb({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final image = ref.watch(fileThumbnailProvider(path, 96)).value;
    return Container(
      width: 44,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.color.pageWhite,
        borderRadius: BorderRadius.circular(t.radius.xs),
        border: Border.all(color: t.color.outline),
      ),
      child: image == null ? null : RawImage(image: image, fit: BoxFit.cover),
    );
  }
}

/// X1's first row for one PDF: Open in viewer (a DkToolRow's look).
class _OpenInViewer extends StatelessWidget {
  const _OpenInViewer({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l.x1_open_in_viewer,
      excludeSemantics: true,
      onTap: onTap,
      child: DkTappable(
        onTap: onTap,
        radius: 0,
        builder: (context, pressed) => Container(
          constraints: const BoxConstraints(minHeight: 56),
          color: pressed ? t.state.pressed : null,
          padding: EdgeInsets.symmetric(vertical: t.space.s),
          child: Row(
            spacing: t.space.m,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.primaryContainer,
                  borderRadius: BorderRadius.circular(t.radius.s),
                ),
                child: Center(
                  child: DkIcon(DkIcons.scanBook, color: c.onPrimaryContainer),
                ),
              ),
              Expanded(
                child: Text(
                  l.x1_open_in_viewer,
                  style: t.text.titleS.copyWith(color: c.textPrimary),
                ),
              ),
              DkIcon(
                DkIcons.chevronRight,
                size: DkIconSize.m,
                color: c.iconSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
