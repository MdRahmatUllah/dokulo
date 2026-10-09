import 'dart:io';

import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_action_bar.dart';
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
import '../t2_tool/tool_options_providers.dart';

/// T3, a tool's result (UI spec §20.4; DK-0379): the result card with the
/// output's pages, its file name, where it will be saved, and Save. Saving
/// keeps the output as a new file next to the input (DK-0381: "Saved to
/// Files › Taxes · Open", then Done). Closing an unsaved result asks first
/// when the job took over 10 s (DK-0382). The result fades in after the
/// progress (the route's transition).
class ToolResultScreen extends ConsumerStatefulWidget {
  const ToolResultScreen({super.key, required this.toolId});

  final String toolId;

  @override
  ConsumerState<ToolResultScreen> createState() => _ToolResultScreenState();
}

/// Closing an unsaved result of a job longer than this asks first.
const confirmDiscardAfter = Duration(seconds: 10);

class _ToolResultScreenState extends ConsumerState<ToolResultScreen> {
  late final ToolResult? _result = ref.read(lastToolResultProvider);
  late final _name = TextEditingController(
    text: _result?.files.firstOrNull?.split(Platform.pathSeparator).last,
  );
  int? _savedId;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

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
      final saved = await store.saveIndexed(
        db,
        File(result.files.first),
        name: _name.text.trim().isEmpty
            ? result.files.first.split(Platform.pathSeparator).last
            : _name.text.trim(),
        subfolder: _subfolder(store),
      );
      await ref.read(hapticsProvider).saved();
      if (!mounted) return;
      setState(() => _savedId = saved.id);
      if (open) {
        context.push(Routes.viewer('${saved.id}'));
      } else {
        showDkToast(
          context,
          l.toast_saved_to(_place(l, store)),
          action: l.common_open,
          onAction: () => context.push(Routes.viewer('${saved.id}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// "Files › Taxes": the user folder, then the save folder's path.
  String _place(AppLocalizations l, FileStore store) => [
    l.shell_tab_files,
    ...?_subfolder(store)?.split(Platform.pathSeparator),
  ].join(' › ');

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
        body: ListView(
          padding: EdgeInsets.all(t.space.l),
          children: [
            DkResultCard(
              headline: formatBytes(size, locale),
              sub: result.files.length == 1
                  ? output.path.split(Platform.pathSeparator).last
                  : l.t2_section_files(result.files.length),
              // Decoration: the headline and the name say what it is.
              preview: isPdf
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
            SizedBox(height: t.space.xl),
            DkTextField(
              label: l.t3_file_name,
              controller: _name,
              enabled: _savedId == null,
            ),
            SizedBox(height: t.space.s),
            if (store != null)
              Text(
                l.t3_save_to(_place(l, store)),
                style: t.text.bodyM.copyWith(color: t.color.textSecondary),
              ),
          ],
        ),
        bottomNavigationBar: DkActionBar(
          label: _savedId == null ? l.t3_save : l.common_done,
          loading: _saving,
          onPressed: _saving ? null : (_savedId == null ? _save : _close),
          secondaryLabel: l.common_open,
          onSecondary: _saving
              ? null
              : () => _savedId == null
                    ? _save(open: true)
                    : context.push(Routes.viewer('$_savedId')),
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
