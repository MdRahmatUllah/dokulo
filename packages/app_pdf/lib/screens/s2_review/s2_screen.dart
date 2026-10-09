import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_icon.dart';
import '../../components/dk_page_tray.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../patterns/dk_undo.dart';
import '../../theme/dk_tokens.dart';
import '../s1_scanner/scan_session.dart';

/// S2, the scan's review (DK-0352; UI spec S2, design
/// `10-scanner/scanner-review-review`, `-reorder`):
///
/// - the bar: "Add pages" (back to the camera), "Review 6 pages", Save;
/// - the current page large on `color.surfaceSunken` (swipe between them)
///   with "3 of 6" under it;
/// - the edit row: Crop · Rotate · Filter · Retake · Delete. Rotate and
///   Delete act here (Delete offers Undo); Crop, Filter and Retake open
///   their states ([onCrop], [onFilter], [onRetake]);
/// - DkPageTray: tap to go to a page, drag to reorder, "+" to add pages.
///
/// The pages are [scanSessionProvider]'s, which keeps them on disk: an
/// unsaved scan is still here after the app was killed.
class S2Screen extends ConsumerStatefulWidget {
  const S2Screen({
    super.key,
    required this.onAddPages,
    this.onSave,
    this.onCrop,
    this.onFilter,
    this.onRetake,
  });

  final VoidCallback onAddPages;

  /// The Save sheet (DK-0359); Save is disabled until it is given.
  final VoidCallback? onSave;

  /// The page's index; null hides nothing, but disables the button.
  final ValueChanged<int>? onCrop, onFilter, onRetake;

  @override
  ConsumerState<S2Screen> createState() => _S2ScreenState();
}

class _S2ScreenState extends ConsumerState<S2Screen> {
  final _pager = PageController();
  var _current = 0;

  @override
  void initState() {
    super.initState();
    // After a kill: bring the unsaved scan back.
    ref.read(scanSessionProvider.notifier).restore();
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _go(int index) {
    setState(() => _current = index);
    if (_pager.hasClients) _pager.jumpToPage(index);
  }

  Future<void> _delete() async {
    final session = ref.read(scanSessionProvider.notifier);
    final l = AppLocalizations.of(context);
    final index = _current;
    final page = await session.remove(index);
    final left = ref.read(scanSessionProvider).length;
    if (left == 0) {
      // ponytail: the last page gone leaves the review; DK-0357 refines it.
      widget.onAddPages();
      return;
    }
    if (_current >= left) _go(left - 1);
    if (!mounted) return;
    await showDkUndo(
      context,
      DkUndo.pageDelete,
      l.toast_page_deleted,
      onUndo: () {
        session.insert(index, page);
        _go(index);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final c = t.color;
    final pages = ref.watch(scanSessionProvider);
    final current = pages.isEmpty ? 0 : _current.clamp(0, pages.length - 1);

    Widget pageImage(ScannedPage p, {BoxFit fit = BoxFit.contain}) =>
        RotatedBox(
          quarterTurns: p.turns,
          child: Image(
            image: ref.read(scanStoreProvider).image(p.path),
            fit: fit,
            gaplessPlayback: true,
          ),
        );

    Widget tool(IconData icon, String label, VoidCallback? onTap) => Expanded(
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 64,
            child: Opacity(
              opacity: onTap == null ? t.state.disabledOpacity : 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: t.space.xxs,
                children: [
                  DkIcon(icon, color: c.iconPrimary),
                  Text(
                    label,
                    style: t.text.caption.copyWith(color: c.textPrimary),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: c.surface,
      appBar: DkTopBar.editing(
        title: l.camera_review(pages.length),
        cancelLabel: l.scan_add_pages,
        onCancel: widget.onAddPages,
        doneLabel: l.common_save,
        onDone: pages.isEmpty ? null : widget.onSave,
      ),
      body: Column(
        children: [
          Expanded(
            child: ColoredBox(
              color: c.surfaceSunken,
              child: pages.isEmpty
                  ? const SizedBox.expand()
                  : Column(
                      children: [
                        Expanded(
                          child: PageView.builder(
                            controller: _pager,
                            itemCount: pages.length,
                            onPageChanged: (i) => setState(() => _current = i),
                            itemBuilder: (context, i) => Padding(
                              padding: EdgeInsets.fromLTRB(
                                t.space.xl,
                                t.space.l,
                                t.space.xl,
                                t.space.s,
                              ),
                              child: pageImage(pages[i]),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: t.space.s),
                          child: Text(
                            l.scan_page_of(current + 1, pages.length),
                            style: t.text.caption.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(top: BorderSide(color: c.outline)),
            ),
            child: Row(
              children: [
                tool(
                  DkIcons.tool('crop'),
                  l.scan_crop,
                  widget.onCrop == null || pages.isEmpty
                      ? null
                      : () => widget.onCrop!(current),
                ),
                tool(
                  DkIcons.tool('rotate'),
                  l.scan_rotate,
                  pages.isEmpty
                      ? null
                      : () => ref
                            .read(scanSessionProvider.notifier)
                            .rotate(current),
                ),
                tool(
                  DkIcons.filters,
                  l.scan_filter,
                  widget.onFilter == null || pages.isEmpty
                      ? null
                      : () => widget.onFilter!(current),
                ),
                tool(
                  DkIcons.retake,
                  l.scan_retake,
                  widget.onRetake == null || pages.isEmpty
                      ? null
                      : () => widget.onRetake!(current),
                ),
                tool(
                  DkIcons.delete,
                  l.common_delete,
                  pages.isEmpty ? null : _delete,
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(top: BorderSide(color: c.outline)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(top: t.space.s),
                child: DkPageTray(
                  pageIds: [for (final p in pages) p.id],
                  pageBuilder: (context, i) =>
                      pageImage(pages[i], fit: BoxFit.cover),
                  current: pages.isEmpty ? null : current,
                  onSelect: _go,
                  onReorder: (from, to) {
                    ref.read(scanSessionProvider.notifier).move(from, to);
                    // The current page follows its move.
                    if (from == current) _go(to);
                  },
                  onAdd: widget.onAddPages,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
