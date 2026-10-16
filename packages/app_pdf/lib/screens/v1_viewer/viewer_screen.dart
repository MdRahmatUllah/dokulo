import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';

import 'dart:async';
import 'dart:io';

import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart' show ManyFiles, Pdf2ImgInput;

import '../../components/dk_action_sheet.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_loading_spinner.dart';
import '../../components/dk_menu.dart';
import '../../components/dk_switch.dart';
import '../../components/dk_banner.dart';
import '../../components/dk_editor_bars.dart';
import '../../components/dk_pdf_canvas.dart';
import '../../components/dk_pdf_search.dart';
import '../../components/dk_skeleton.dart';
import '../../components/dk_toast.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../routes/routes.dart';
import '../../theme/dk_layout.dart';
import '../../theme/dk_tokens.dart';
import '../../patterns/dk_file_actions.dart';
import '../../patterns/dk_file_info.dart';
import '../../patterns/dk_tool_picker.dart';
import '../../patterns/dk_viewer_dialogs.dart';
import '../../providers/file_providers.dart';
import '../../providers/files_providers.dart';
import '../../providers/share_providers.dart';
import '../../providers/link_providers.dart';
import '../../providers/prefs_providers.dart';
import '../../providers/print_providers.dart';
import '../t2_tool/tool_run.dart';
import 'viewer_chrome.dart';
import 'viewer_providers.dart';
import 'viewer_search.dart';
import 'viewer_states.dart';
import 'viewer_tablet.dart';
import 'viewer_thumb_strip.dart';

/// V1, the viewer (UI spec §17.1). This is its core (DK-0293): the file's
/// pages on [DkPdfCanvas]; while the file opens, the page skeleton (DK-0620).
/// A locked PDF asks for its password, a damaged one says so (DK-0301..
/// DK-0305). Around the pages, [ViewerChrome] (DK-0294): the top bar, the
/// page pill and the bottom bar, hidden on a tap or after scrolling; while
/// searching, the search bar takes the top bar's place.
/// The prefs key of V1's night mode (UI spec §17.1; DK-1089).
const viewerNightKey = 'viewer.night';

class ViewerScreen extends ConsumerStatefulWidget {
  const ViewerScreen({super.key, required this.fileId, this.page, this.query});

  final int fileId;

  /// Where it opens, 1-based (a search hit, DK-0269); the first page if null.
  // ponytail: the page only; the hit's term is highlighted once V1 search
  // lands, which will take it as a second parameter.
  final int? page;

  /// Opens searching these words (a Files search hit, DK-1093).
  final String? query;

  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen> {
  /// The password that opened a locked PDF, for this visit only.
  String? _password;

  /// Text search (DK-1093); [_searching] shows its bar.
  late final _search = DkPdfSearch()..search(widget.query ?? '');
  late var _searching = (widget.query ?? '').isNotEmpty;

  /// The page pill's numbers (DK-0294).
  int? _page;
  var _pageCount = 0;
  final _controller = PdfViewerController();

  /// V1's bottom bar, drawn in the body: toasts go above it.
  double get _barHeight => 64 + MediaQuery.paddingOf(context).bottom;

  /// The thumbnail strip, from Pages in the overflow menu (DK-0295).
  var _thumbs = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Locked: does [password] open it? Then the pages, and "Unlocked for
  /// viewing · Remove password" (DK-0303).
  Future<bool> _unlock(String path, String password) async {
    final opens =
        await ref.read(viewerOpenProvider(path, password: password).future) ==
        ViewerOpen.ok;
    if (!opens || !mounted) return opens;
    setState(() => _password = password);
    final l = AppLocalizations.of(context);
    showDkToast(
      context,
      l.viewer_unlocked,
      above: _barHeight,
      action: l.tool_unlock_name,
      onAction: () {
        if (mounted) {
          context.push(Routes.tool('unlock', files: ['${widget.fileId}']));
        }
      },
    );
    return true;
  }

  /// Highlight, Underline or Strike from the selection (DK-0321): the
  /// annotations go straight into a new copy of the file (edit mode,
  /// unseen), the old content is kept as a version, and "Saved · Undo"
  /// puts it back. The colour is the highlighter's last-used one.
  Future<void> _markup(
    String path,
    DkMarkupAction action,
    List<SelectionLines> selected,
  ) async {
    final l = AppLocalizations.of(context);
    final saved = ref.read(prefsProvider).value?['edit.options.highlighter'];
    final colour = saved is Map && saved['color'] is int
        ? Color(saved['color'] as int)
        : context.tokens.markup.yellow;
    final edits = markupEdits(action, selected, colour);
    if (edits.isEmpty) return;
    // Everything from ref before the first await: the user may leave.
    final storeFuture = ref.read(fileStoreProvider.future);
    final versionsFuture = ref.read(versionStoreProvider.future);
    File? out;
    try {
      out = await (await storeFuture).newTempFile(
        path.split(RegExp(r'[\\/]')).last,
      );
      await PdfAnnotations.apply(path, out.path, edits, password: _password);
      final versions = await versionsFuture;
      final before = await versions.replace(widget.fileId, out.path);
      if (!mounted) return;
      _reload();
      showDkToast(
        context,
        l.toast_saved,
        action: l.common_undo,
        above: _barHeight,
        onAction: () async {
          await versions.restore(before);
          if (mounted) _reload();
        },
      );
    } catch (_) {
      if (mounted) {
        showDkToast(context, l.viewer_markup_failed, above: _barHeight);
      }
    } finally {
      if (out != null && await out.exists()) await out.delete();
    }
  }

  /// The file was rewritten: the canvas opens it again, on the same page.
  var _revision = 0;

  void _reload() {
    ref.invalidate(viewerFileProvider(widget.fileId));
    setState(() => _revision++);
  }

  @override
  Widget build(BuildContext context) {
    final file = ref.watch(viewerFileProvider(widget.fileId));
    return Scaffold(
      backgroundColor: context.tokens.color.surfaceSunken,
      body: switch (file) {
        AsyncData(:final value) => Column(
          children: [
            if (_searching) ...[
              ViewerSearchBar(
                search: _search,
                onDone: () => setState(() {
                  _searching = false;
                  _search.search('');
                }),
              ),
              // A scan without a text layer finds nothing (§17.1).
              if (ref
                      .watch(
                        viewerHasTextProvider(value.path, password: _password),
                      )
                      .value ==
                  false)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.tokens.space.m,
                    context.tokens.space.s,
                    context.tokens.space.m,
                    0,
                  ),
                  child: DkBanner(
                    text: AppLocalizations.of(context).viewer_search_no_text,
                    action: AppLocalizations.of(context).viewer_make_searchable,
                    onAction: () => context.push(
                      Routes.tool('ocr', files: ['${widget.fileId}']),
                    ),
                  ),
                ),
            ],
            Expanded(
              child: _searching
                  ? _pages(value.path)
                  : DkGrid.forWidth(MediaQuery.sizeOf(context).width) !=
                        DkGrid.phone
                  // A tablet: the actions in the top bar, thumbnails down
                  // the side (§17.4; DK-0310).
                  ? ViewerTabletChrome(
                      name: value.name,
                      page: _page,
                      pageCount: _pageCount,
                      actions: _actions(value),
                      canvas: _pages(value.path),
                      sidebar: ViewerThumbStrip(
                        path: value.path,
                        pageCount: _pageCount,
                        current: _page ?? 1,
                        axis: Axis.vertical,
                        onPage: (p) => _controller.goToPage(pageNumber: p),
                      ),
                      // The pages reflow to the new width: back to the
                      // page that was showing.
                      onSidebarToggled: () {
                        final page = _page;
                        if (page == null) return;
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _controller.goToPage(pageNumber: page),
                        );
                      },
                    )
                  : ViewerChrome(
                      name: value.name,
                      page: _page,
                      pageCount: _pageCount,
                      actions: _actions(value),
                      strip: _thumbs && _pageCount > 0
                          ? ViewerThumbStrip(
                              path: value.path,
                              pageCount: _pageCount,
                              current: _page ?? 1,
                              onPage: (p) =>
                                  _controller.goToPage(pageNumber: p),
                            )
                          : null,
                      canvas: (onTap, onScrollStart) => _pages(
                        value.path,
                        onTap: onTap,
                        onScrollStart: onScrollStart,
                        // The bars lie over the pages (DK-1111).
                        insets: EdgeInsets.only(
                          top:
                              DkTopBar.height +
                              MediaQuery.paddingOf(context).top,
                          bottom: _barHeight,
                        ),
                      ),
                    ),
            ),
          ],
        ),
        // The file's row is gone (deleted, or a stale link).
        AsyncError() => Center(
          child: Padding(
            padding: EdgeInsets.all(context.tokens.space.xl),
            child: Text(
              AppLocalizations.of(context).viewer_file_missing,
              style: context.tokens.text.bodyM.copyWith(
                color: context.tokens.color.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => const ViewerPageSkeleton(),
      },
    );
  }

  /// The viewer's actions, the same on a phone and a tablet.
  ViewerActions _actions(FileEntry value) => ViewerActions(
    onSearch: () => setState(() => _searching = true),
    // V2 with Pan and the signatures sheet (§17.2).
    onSign: () => context.push(Routes.viewer('${widget.fileId}', sign: true)),
    onAi: () =>
        context.push(Routes.tool('summarize', files: ['${widget.fileId}'])),
    onEdit: () => context.push(Routes.viewer('${widget.fileId}', edit: true)),
    onRename: () => renameFile(context, ref, value),
    // X1 with this file (DK-1094).
    onTools: () => showToolPicker(context, [value]),
    onOverflow: (anchor) => _menu(anchor, value),
    onShare: () => ref.read(fileSharerProvider)([value.path]),
  );

  /// The overflow menu (DK-0295; UI spec §17.1, viewer-menu): Info · Go to
  /// page · Pages · Night mode · Organize pages · Print · Share as images ·
  /// Share text (DK-0311) · Move to locked folder, then Delete (to Recently
  /// deleted with Undo; the viewer closes).
  void _menu(BuildContext anchor, FileEntry file) {
    final l = AppLocalizations.of(context);
    final night = ref.read(prefsProvider).value?[viewerNightKey] == true;
    showDkMenu(
      anchor,
      groups: [
        [
          DkAction(
            icon: DkIcons.info,
            label: l.common_info,
            onTap: () => showFileInfo(context, file),
          ),
          DkAction(
            icon: DkIcons.goToPage,
            label: l.viewer_goto_title,
            onTap: () async {
              final page = await showGoToPage(
                context,
                pageCount: _pageCount,
                current: _page,
              );
              if (page != null) await _controller.goToPage(pageNumber: page);
            },
          ),
          DkAction(
            icon: DkIcons.pages,
            label: l.viewer_menu_pages,
            onTap: () => setState(() => _thumbs = !_thumbs),
          ),
          DkAction(
            icon: DkIcons.nightMode,
            label: l.viewer_menu_night,
            // The row toggles it; the switch only shows the state.
            trailing: IgnorePointer(
              child: ExcludeSemantics(
                child: DkSwitch(value: night, onChanged: (_) {}),
              ),
            ),
            onTap: () =>
                ref.read(prefsProvider.notifier).set(viewerNightKey, !night),
          ),
          DkAction(
            icon: DkIcons.gridView,
            label: l.tool_organize_name,
            onTap: () => context.push(Routes.organize('${file.id}')),
          ),
          DkAction(
            icon: DkIcons.print,
            label: l.viewer_menu_print,
            onTap: () async {
              final opened = await ref.read(pdfPrinterProvider)(
                file.path,
                file.name,
              );
              if (!opened && mounted) {
                showDkToast(context, l.viewer_print_failed, above: _barHeight);
              }
            },
          ),
          DkAction(
            icon: DkIcons.tool('pdf2img'),
            label: l.viewer_menu_share_images,
            onTap: () => _shareImages(file),
          ),
          DkAction(
            icon: DkIcons.tool('text'),
            label: l.viewer_menu_share_text,
            onTap: () => _shareText(file),
          ),
          DkAction(
            icon: DkIcons.lockedFolder,
            label: l.file_move_to_locked,
            onTap: () => context.push(Routes.lockedFolder, extra: [file.id]),
          ),
        ],
        [
          DkAction(
            icon: DkIcons.delete,
            label: l.common_delete,
            destructive: true,
            onTap: () {
              // The toast outlives the viewer: it goes on the app's
              // messenger, from above this route.
              final root = Navigator.of(context, rootNavigator: true).context;
              unawaited(deleteFiles(root, ref, [file]));
              Navigator.of(context).maybePop();
            },
          ),
        ],
      ],
    );
  }

  /// Share as images (DK-0311): every page as a 150 dpi JPG through the
  /// pdf2img job, then the real files to the share sheet. A long document
  /// says it's preparing them.
  Future<void> _shareImages(FileEntry file) async {
    final l = AppLocalizations.of(context);
    if (_pageCount > 10) {
      showDkToast(context, l.viewer_share_preparing, above: _barHeight);
    }
    try {
      final run = await ref.read(toolRunnerProvider)(
        'pdf2img',
        (out) => Pdf2ImgInput(
          file: file.path,
          outputDir: out,
          suffix: l.viewer_share_page_suffix,
          password: _password,
        ),
      );
      final images = await run.result as ManyFiles;
      await ref.read(fileSharerProvider)(images.paths);
    } catch (_) {
      if (mounted) {
        showDkToast(context, l.viewer_share_failed, above: _barHeight);
      }
    }
  }

  /// Share text (DK-0311): the pages' text, a blank line between pages, to
  /// the share sheet; a scan without a text layer says so.
  Future<void> _shareText(FileEntry file) async {
    final l = AppLocalizations.of(context);
    try {
      final pages = await PdfEngine.pageTexts(file.path, password: _password);
      final text = pages.map((p) => p.trim()).where((p) => p.isNotEmpty);
      if (text.isEmpty) {
        if (mounted) {
          showDkToast(context, l.viewer_search_no_text, above: _barHeight);
        }
        return;
      }
      await ref.read(textSharerProvider)(text.join('\n\n'));
    } catch (_) {
      if (mounted) {
        showDkToast(context, l.viewer_share_failed, above: _barHeight);
      }
    }
  }

  /// The form banner over the first page (UI spec §17.1; DK-1090): "This
  /// PDF has fillable fields." with Fill form.
  Widget _withFormBanner(String path, double top, Widget pages) {
    final hasForm =
        ref.watch(viewerHasFormProvider(path, password: _password)).value ==
        true;
    if (!hasForm) return pages;
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return Stack(
      children: [
        pages,
        Positioned(
          left: t.space.m,
          right: t.space.m,
          top: top + t.space.m,
          child: DkBanner(
            text: l.viewer_form_banner,
            action: l.viewer_form_fill,
            onAction: () =>
                context.push(Routes.tool('form', files: ['${widget.fileId}'])),
          ),
        ),
      ],
    );
  }

  /// The pages, or the locked card or the damaged state (DK-0301, DK-0305).
  Widget _pages(
    String path, {
    VoidCallback? onTap,
    VoidCallback? onScrollStart,
    EdgeInsets insets = EdgeInsets.zero,
  }) {
    final open = ref.watch(viewerOpenProvider(path, password: _password));
    return switch (open.value) {
      ViewerOpen.ok => _withFormBanner(
        path,
        insets.top,
        DkPdfCanvas(
          path: path,
          insets: insets,
          password: _password,
          controller: _controller,
          onTap: onTap,
          onScrollStart: onScrollStart,
          onReady: () => setState(() {
            _pageCount = _controller.pageCount;
            _page = _controller.pageNumber ?? 1;
          }),
          onPageChanged: (p) => setState(() => _page = p ?? _page),
          // Night mode (DK-1089), switched in the overflow menu (DK-0295).
          night: ref.watch(prefsProvider).value?[viewerNightKey] == true,
          markup: DkMarkupAction.values,
          onMarkup: (action, lines) => _markup(path, action, lines),
          // A1 Ask with the selection in its composer (§17.1).
          onAsk: (text) => context.push(
            Routes.tool('ask', files: ['${widget.fileId}'], prompt: text),
          ),
          search: _search,
          revision: _revision,
          initialPage: (_revision == 0 ? widget.page : _page) ?? 1,
          // A web link asks first; it's the only step that leaves Dokulo
          // (DK-1088).
          onLink: (url) async {
            if (await confirmOpenLink(context, url)) {
              await ref.read(linkOpenerProvider)(url);
            }
          },
        ),
      ),
      ViewerOpen.locked => ViewerLockedCard(
        onUnlock: (password) => _unlock(path, password),
      ),
      ViewerOpen.damaged => ViewerDamaged(
        onClose: () => Navigator.of(context).maybePop(),
        onRepair: () =>
            context.push(Routes.tool('repair', files: ['${widget.fileId}'])),
      ),
      null => const ViewerPageSkeleton(),
    };
  }
}

/// V1 loading (UI spec §26.2, viewer-loading): the first page as an A4
/// skeleton with a large spinner on it, the next page's top below, 8 from
/// the edges. The pages are `color.surface` on the viewer's
/// `color.surfaceSunken` (the artboard draws them in the background's own
/// colour, so only the spinner would show), pulsing as any DkSkeleton.
class ViewerPageSkeleton extends StatelessWidget {
  const ViewerPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final page = DecoratedBox(
      decoration: BoxDecoration(
        color: t.color.surface,
        borderRadius: BorderRadius.circular(t.radius.xs),
      ),
    );
    final a4 = AspectRatio(aspectRatio: 1 / 1.4142, child: page);
    // Pages as the viewer lays them out, cut off by the screen's edge
    // (any height, any orientation).
    return DkSkeleton(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(t.space.s),
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              a4,
              DkLoadingSpinner(
                size: DkSpinnerSize.large,
                color: t.color.textDisabled, // the artboard's --t3
              ),
            ],
          ),
          SizedBox(height: t.space.s),
          a4,
        ],
      ),
    );
  }
}

/// The annotations for [action] on [selected] (DK-0321): one markup per
/// page, a quad per line. A highlight at 40 % (or the colour's own alpha);
/// Underline and Strike opaque.
Map<int, PageAnnotEdits> markupEdits(
  DkMarkupAction action,
  List<SelectionLines> selected,
  Color colour,
) {
  final kind = switch (action) {
    DkMarkupAction.highlight => MarkupKind.highlight,
    DkMarkupAction.underline => MarkupKind.underline,
    DkMarkupAction.strike => MarkupKind.strikeOut,
    _ => null,
  };
  if (kind == null) return const {};
  final argb = kind == MarkupKind.highlight
      ? (colour.a < 1 ? colour : colour.withValues(alpha: 0.4)).toARGB32()
      : colour.withValues(alpha: 1).toARGB32();
  return {
    for (final s in selected)
      if (s.lines.isNotEmpty)
        s.page: PageAnnotEdits(
          add: [
            MarkupAnnot(kind, [
              for (final line in s.lines) _quad(line),
            ], color: argb),
          ],
        ),
  };
}

/// A line's quad, corners in the PDF order (upper left, upper right, lower
/// left, lower right) as the text reads: an underline runs under the letters
/// on sideways or upside-down text too (DK-1138).
MarkupQuad _quad(LineRun line) {
  final b = line.box;
  final (lt, rt, lb, rb) = (
    (x: b.left, y: b.top),
    (x: b.right, y: b.top),
    (x: b.left, y: b.bottom),
    (x: b.right, y: b.bottom),
  );
  return switch (line.dir) {
    LineDir.right => (lt, rt, lb, rb),
    LineDir.up => (lb, lt, rb, rt),
    LineDir.left => (rb, lb, rt, lt),
    LineDir.down => (rt, rb, lt, lb),
  };
}
