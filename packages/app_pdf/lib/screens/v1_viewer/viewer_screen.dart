import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';

import 'dart:async';

import 'package:doc_core/doc_core.dart';

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
import '../../l10n/app_localizations.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';
import '../../patterns/dk_file_actions.dart';
import '../../patterns/dk_file_info.dart';
import '../../patterns/dk_tool_picker.dart';
import '../../patterns/dk_viewer_dialogs.dart';
import '../../providers/file_providers.dart';
import '../../providers/files_providers.dart';
import '../../providers/link_providers.dart';
import '../../providers/prefs_providers.dart';
import '../../providers/print_providers.dart';
import 'viewer_chrome.dart';
import 'viewer_providers.dart';
import 'viewer_search.dart';
import 'viewer_states.dart';
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
    final out = await (await ref.read(fileStoreProvider.future))
        .newTempFile(path.split(RegExp(r'[\\/]')).last);
    await PdfAnnotations.apply(path, out.path, edits, password: _password);
    final versions = await ref.read(versionStoreProvider.future);
    final before = await versions.replace(widget.fileId, out.path);
    if (!mounted) return;
    showDkToast(
      context,
      l.toast_saved,
      action: l.common_undo,
      onAction: () => versions.restore(before),
    );
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
                  : ViewerChrome(
                      name: value.name,
                      page: _page,
                      pageCount: _pageCount,
                      actions: ViewerActions(
                        onSearch: () => setState(() => _searching = true),
                        onSign: () => context.push(
                          Routes.tool('sign', files: ['${widget.fileId}']),
                        ),
                        onAi: () => context.push(
                          Routes.tool('summarize', files: ['${widget.fileId}']),
                        ),
                        onEdit: () => context.push(
                          Routes.viewer('${widget.fileId}', edit: true),
                        ),
                        onRename: () => renameFile(context, ref, value),
                        // X1 with this file (DK-1094).
                        onTools: () => showToolPicker(context, [value]),
                        onOverflow: (anchor) => _menu(anchor, value),
                      ),
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

  /// The overflow menu (DK-0295; UI spec §17.1, viewer-menu): Info · Go to
  /// page · Pages · Night mode · Organize pages · Print · Move to locked
  /// folder, then Delete (to Recently deleted with Undo; the viewer closes).
  // ponytail: Share as images and Share text join with share_plus (DK-0311).
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
                showDkToast(context, l.viewer_print_failed);
              }
            },
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

  /// The form banner over the first page (UI spec §17.1; DK-1090): "This
  /// PDF has fillable fields." with Fill form.
  Widget _withFormBanner(String path, Widget pages) {
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
          top: t.space.m,
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
  }) {
    final open = ref.watch(viewerOpenProvider(path, password: _password));
    return switch (open.value) {
      ViewerOpen.ok => _withFormBanner(
        path,
        DkPdfCanvas(
          path: path,
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
          // Copy for now; Highlight, Underline, Strike come with the
          // annotations (DK-0321), Ask AI with the AI pane (M13).
          markup: const [
            DkMarkupAction.copy,
            DkMarkupAction.highlight,
            DkMarkupAction.underline,
            DkMarkupAction.strike,
          ],
          onMarkup: (action, lines) => _markup(path, action, lines),
          search: _search,
          initialPage: widget.page ?? 1,
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
              for (final b in s.lines)
                (
                  (x: b.left, y: b.top),
                  (x: b.right, y: b.top),
                  (x: b.left, y: b.bottom),
                  (x: b.right, y: b.bottom),
                ),
            ], color: argb),
          ],
        ),
  };
}
