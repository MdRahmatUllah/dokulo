import 'dart:io';

import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_action_bar.dart';
import '../../components/dk_button.dart';
import '../../components/dk_file_card.dart';
import '../../components/dk_next_chip.dart';
import '../../components/dk_pdf_canvas.dart';
import '../../components/dk_page_thumb.dart';
import '../../components/dk_result_card.dart';
import '../../components/dk_text_field.dart';
import '../../components/dk_toast.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/formats.dart';
import '../../patterns/dk_confirmations.dart';
import '../../providers/database_providers.dart';
import '../../providers/file_providers.dart';
import '../../routes/link_error.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';
import '../../theme/haptics.dart';
import '../../tools/tool_catalogue.dart';
import '../../tools/tool_definition.dart';
import '../../tools/tool_inputs.dart';
import '../t2_tool/tool_layout.dart';
import '../t2_tool/tool_options_providers.dart';

/// T3, a tool's result (UI spec §20.4; DK-0379): the result card with the
/// output's pages, its file name, where it will be saved, and Save. Saving
/// keeps the output as a new file next to the input (DK-0381: "Saved to
/// Files › Taxes · Open", then Done). Closing an unsaved result asks first
/// when the job took over 10 s (DK-0382). The result fades in after the
/// progress (the route's transition).
class ToolResultScreen extends ConsumerStatefulWidget {
  const ToolResultScreen({super.key, required this.toolId, this.definition});

  final String toolId;

  /// The tool's definition (its card and part lines); null: the app's.
  final ToolDefinition? definition;

  @override
  ConsumerState<ToolResultScreen> createState() => _ToolResultScreenState();
}

/// Closing an unsaved result of a job longer than this asks first.
const confirmDiscardAfter = Duration(seconds: 10);

class _ToolResultScreenState extends ConsumerState<ToolResultScreen> {
  late final ToolResult? _result = ref.read(lastToolResultProvider);
  late final _name = TextEditingController(
    text: switch (_result?.files.firstOrNull) {
      final String path => File(path).uri.pathSegments.last,
      null => null,
    },
  );
  int? _savedId;

  /// What Save kept, for a Next chip after saving.
  var _savedFiles = const <FileEntry>[];
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  ToolDefinition get _def =>
      widget.definition ?? ToolDefinitions.of(widget.toolId);

  /// Where Save puts it: next to the (first) input, or the user folder.
  String? _subfolder(FileStore store) =>
      store.subfolderOf(_result!.inputs.firstOrNull?.path ?? '');

  Future<void> _save({bool open = false}) async {
    final result = _result!;
    final l = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final store = await ref.read(fileStoreProvider.future);
      final db = ref.read(appDatabaseProvider);
      // One file takes the typed name; the parts of a multi-file result
      // keep theirs (DK-0384).
      final many = result.files.length > 1;
      final saved = <FileEntry>[];
      for (final f in result.files) {
        saved.add(
          await store.saveIndexed(
            db,
            File(f),
            name: many ? File(f).uri.pathSegments.last : _fileName(f),
            subfolder: _subfolder(store),
          ),
        );
      }
      _savedFiles = saved;
      final first = saved.first;
      await ref.read(hapticsProvider).saved();
      if (!mounted) return;
      setState(() => _savedId = first.id);
      if (open) {
        context.push(Routes.viewer('${first.id}'));
      } else {
        showDkToast(
          context,
          l.toast_saved_to(_place(l, store)),
          action: l.common_open,
          onAction: () => context.push(Routes.viewer('${first.id}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The name typed, with the output's extension kept ("Bescheid" saves as
  /// "Bescheid.pdf"); empty: the output's own name.
  String _fileName(String output) {
    final own = File(output).uri.pathSegments.last;
    final typed = _name.text.trim();
    if (typed.isEmpty) return own;
    final dot = own.lastIndexOf('.');
    final ext = dot > 0 ? own.substring(dot) : '';
    return typed.toLowerCase().endsWith(ext.toLowerCase())
        ? typed
        : '$typed$ext';
  }

  /// "Files › Taxes": the user folder, then the save folder's path.
  String _place(AppLocalizations l, FileStore store) => [
    l.shell_tab_files,
    ...?_subfolder(store)?.split(Platform.pathSeparator),
  ].join(' › ');

  /// A Next chip (DK-0386): the next tool opens with this result as its
  /// input, no re-pick; it takes T3's place. Unsaved, the output files go
  /// as they are (out of the index); saved, the saved ones.
  Future<void> _chainTo(String toolId) async {
    final result = _result!;
    final files = _savedFiles.isNotEmpty
        ? _savedFiles
        : [
            for (final (i, path) in result.files.indexed)
              await _unsaved(path, -1 - i),
          ];
    ref.read(chainInputProvider.notifier).set(files, result.chain);
    if (mounted) {
      context.pushReplacement(Routes.tool(toolId, chained: true));
    }
  }

  /// An output not saved yet, as an input entry (out of the index).
  static Future<FileEntry> _unsaved(String path, int id) async {
    final file = File(path);
    final stat = await file.stat();
    var pages = 0;
    if (ToolInput.kindOf(path) == DkFileKind.pdf) {
      try {
        pages = (await PdfEngine.inspect(path)).pageCount;
      } on DocError {
        // The next tool's own check says why.
      }
    }
    return FileEntry(
      id: id,
      path: path,
      name: file.uri.pathSegments.last,
      size: stat.size,
      pages: pages,
      created: stat.changed,
      modified: stat.modified,
      hasText: false,
      encrypted: false,
    );
  }

  /// "From Zeugnisse.pdf · 34 pages": the (first) input; or the output's
  /// name when the run had no input file.
  String _from(AppLocalizations l, ToolResult result) {
    final input = result.inputs.firstOrNull;
    if (input == null) {
      return File(result.files.first).uri.pathSegments.last;
    }
    return l.t3_from(
      [input.name, if (input.pages > 0) l.meta_pages(input.pages)].join(' · '),
    );
  }

  /// Back to where the tool was started (T3 took T2's place).
  Future<void> _close() async {
    if (_savedId == null) {
      final long = _result!.took > confirmDiscardAfter;
      if (long && !await confirmDk(context, DkConfirmation.discardResult)) {
        return;
      }
      for (final f in _result.files) {
        final file = File(f);
        if (await file.exists()) await file.delete();
      }
    }
    if (!mounted) return;
    // A deep-linked T3 has nothing beneath: Home.
    context.canPop() ? context.pop() : context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    // A stale link to a result: nothing to show.
    if (result == null ||
        result.toolId != widget.toolId ||
        result.files.isEmpty) {
      return const LinkErrorScreen();
    }
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final tool = ToolCatalogue.of(widget.toolId);
    final output = File(result.files.first);
    final size = output.existsSync() ? output.lengthSync() : 0;
    final store = ref.watch(fileStoreProvider).value;
    final isPdf = output.path.toLowerCase().endsWith('.pdf');
    final many = result.files.length > 1;
    final nextTools = [
      for (final id in _def.next)
        if (ToolInput.of(id) case final input?
            when input.takes(output.path) && result.files.length <= input.max)
          id,
    ];
    final summary =
        _def.summary?.call(l, result) ??
        ToolSummary(
          headline: many
              ? l.t3_files(result.files.length)
              : formatBytes(size, locale),
          sub: _from(l, result),
        );
    final actions = DkActionBar(
      label: _savedId == null ? l.t3_save : l.common_done,
      loading: _saving,
      onPressed: _saving ? null : (_savedId == null ? _save : _close),
      secondaryLabel: l.common_open,
      onSecondary: _saving
          ? null
          : () => _savedId == null
                ? _save(open: true)
                : context.push(Routes.viewer('$_savedId')),
    );
    // A large tablet's preview pane (DK-0388): the result.
    final Widget? preview = isPdf ? DkPdfCanvas(path: output.path) : null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: t.color.background,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(DkTopBar.height),
          child: DkTopBar(
            title: tool.name(l),
            leading: DkTopBarLeading.close,
            onLeading: _close,
          ),
        ),
        body: ToolLayout(
          content: ListView(
            padding: EdgeInsets.all(t.space.l),
            children: [
              DkResultCard(
                headline: summary.headline,
                delta: summary.delta,
                sub: summary.sub,
                partial: summary.partial,
                action: summary.action == null
                    ? null
                    : DkButton(
                        label: summary.action!,
                        variant: DkButtonVariant.secondary,
                        size: DkButtonSize.compact,
                        onPressed: () => summary.onAction!(context),
                      ),
                // Decoration: the headline and the name say what it is.
                preview: isPdf && !many
                    ? ExcludeSemantics(
                        child: Row(
                          spacing: t.space.s,
                          children: [
                            for (var page = 1; page <= 4; page++)
                              SizedBox(
                                width: 48,
                                child: _PreviewPage(
                                  path: output.path,
                                  page: page,
                                ),
                              ),
                          ],
                        ),
                      )
                    : null,
              ),
              if (many) ...[
                Padding(
                  padding: EdgeInsets.only(top: t.space.xl, bottom: t.space.s),
                  child: Semantics(
                    container: true,
                    header: true,
                    child: Text(
                      l.t3_files(result.files.length),
                      style: t.text.titleS.copyWith(color: t.color.textPrimary),
                    ),
                  ),
                ),
                // The parts (DK-0384): edge to edge, as file rows are.
                for (final (i, f) in result.files.indexed)
                  Transform.translate(
                    offset: Offset(-t.space.l, 0),
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width,
                      child: DkFileCard(
                        name: File(f).uri.pathSegments.last,
                        meta:
                            _def.partLine?.call(l, result, i) ??
                            formatBytes(
                              File(f).existsSync() ? File(f).lengthSync() : 0,
                              locale,
                            ),
                        onTap: () {},
                      ),
                    ),
                  ),
              ],
              if (!many) ...[
                SizedBox(height: t.space.xl),
                DkTextField(
                  label: l.t3_file_name,
                  controller: _name,
                  enabled: _savedId == null,
                ),
              ],
              SizedBox(height: t.space.s),
              if (store != null)
                Text(
                  l.t3_save_to(_place(l, store)),
                  style: t.text.bodyM.copyWith(color: t.color.textSecondary),
                ),
              // What next (UI spec §20.4): the tools that take this result.
              if (nextTools.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.only(top: t.space.l, bottom: t.space.s),
                  child: Semantics(
                    container: true,
                    header: true,
                    child: Text(
                      l.common_next,
                      style: t.text.titleS.copyWith(color: t.color.textPrimary),
                    ),
                  ),
                ),
                Wrap(
                  spacing: t.space.s,
                  runSpacing: t.space.s,
                  children: [
                    for (final id in nextTools)
                      DkNextChip(toolId: id, onTap: () => _chainTo(id)),
                  ],
                ),
              ],
            ],
          ),
          actions: actions,
          preview: preview,
          previewTitle: l.t3_result_preview,
        ),
        bottomNavigationBar: ToolLayout.bottom(
          context,
          actions,
          preview: preview != null,
        ),
      ),
    );
  }
}

/// An output page in the preview strip; a page past the end shows nothing.
class _PreviewPage extends ConsumerWidget {
  const _PreviewPage({required this.path, required this.page});

  final String path;
  final int page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(pdfThumbnailProvider(path, page: page));
    if (image.hasError) return const SizedBox.shrink();
    return DkPageThumb(
      pageNumber: page,
      pageCount: page,
      showNumber: false,
      page: image.value == null ? null : RawImage(image: image.value),
    );
  }
}
