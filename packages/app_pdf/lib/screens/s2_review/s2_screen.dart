import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_button.dart';
import '../../components/dk_chip.dart';
import '../../components/dk_crop_overlay.dart';
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
///   Delete act here (Delete offers Undo); Filter and Retake open their
///   states ([onFilter], [onRetake]);
/// - crop mode (DK-0353, `scanner-review-crop`): the uncropped photo in
///   DkCropOverlay (Auto · Full page · Reset, the magnifier while a corner
///   is dragged), Cancel / Apply under it. After Full page or a rotation, a
///   chip "Apply to all pages" does the same to every page;
/// - DkPageTray: tap to go to a page, drag to reorder, "+" to add pages.
///
/// The pages are [scanSessionProvider]'s, which keeps them on disk: an
/// unsaved scan is still here after the app was killed.
class S2Screen extends ConsumerStatefulWidget {
  const S2Screen({
    super.key,
    required this.onAddPages,
    this.onSave,
    this.onFilter,
    this.onRetake,
  });

  final VoidCallback onAddPages;

  /// The Save sheet (DK-0359); Save is disabled until it is given.
  final VoidCallback? onSave;

  /// The page's index; null hides nothing, but disables the button.
  final ValueChanged<int>? onFilter, onRetake;

  @override
  ConsumerState<S2Screen> createState() => _S2ScreenState();
}

class _S2ScreenState extends ConsumerState<S2Screen> {
  final _pager = PageController();
  var _current = 0;

  /// Crop mode: the quad being edited and the one it started from, and the
  /// photo's width : height (3:4 until the photo has loaded).
  DetectedQuad? _draft, _cropStart;
  var _aspect = 3 / 4;

  /// The chip after Full page or a rotation: does it to every page.
  Future<void> Function()? _applyAll;

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
    setState(() {
      _current = index;
      _applyAll = null;
    });
    if (_pager.hasClients) _pager.jumpToPage(index);
  }

  void _crop(ScannedPage page) {
    setState(() {
      _draft = _cropStart = page.corners;
      _applyAll = null;
    });
    final stream = ref
        .read(scanStoreProvider)
        .image(page.path)
        .resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      stream.removeListener(listener);
      if (mounted) {
        setState(() => _aspect = info.image.width / info.image.height);
      }
      info.dispose();
    }, onError: (_, _) => stream.removeListener(listener));
    stream.addListener(listener);
  }

  Future<void> _applyCrop(int index) async {
    final crop = _draft!;
    setState(() => _draft = null);
    final session = ref.read(scanSessionProvider.notifier);
    await session.setCrop(index, crop);
    if (!mounted) return;
    setState(
      () => _applyAll = listEquals(crop, ScannedPage.fullPage)
          ? () => session.applyToAll(crop: ScannedPage.fullPage)
          : null,
    );
  }

  Future<void> _rotate(int index) async {
    final session = ref.read(scanSessionProvider.notifier);
    await session.rotate(index);
    final turns = ref.read(scanSessionProvider)[index].turns;
    if (mounted) {
      setState(() => _applyAll = () => session.applyToAll(turns: turns));
    }
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
    final draft = pages.isEmpty ? null : _draft;

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
                  : draft != null
                  ? _cropView(pages[current], draft)
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
          if (draft != null)
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.outline)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.all(t.space.m),
                  child: Row(
                    spacing: t.space.m,
                    children: [
                      Expanded(
                        child: DkButton(
                          label: l.common_cancel,
                          variant: DkButtonVariant.secondary,
                          expand: true,
                          onPressed: () => setState(() => _draft = null),
                        ),
                      ),
                      Expanded(
                        child: DkButton(
                          label: l.common_apply,
                          expand: true,
                          onPressed: () => _applyCrop(current),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (draft == null && _applyAll != null)
            ColoredBox(
              color: c.surface,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  t.space.l,
                  t.space.s,
                  t.space.l,
                  t.space.xxs,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DkChip(
                    label: l.common_apply_all,
                    selected: false,
                    onSelected: (_) async {
                      final apply = _applyAll!;
                      setState(() => _applyAll = null);
                      await apply();
                    },
                  ),
                ),
              ),
            ),
          if (draft == null) ...[
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
                    pages.isEmpty ? null : () => _crop(pages[current]),
                  ),
                  tool(
                    DkIcons.tool('rotate'),
                    l.scan_rotate,
                    pages.isEmpty ? null : () => _rotate(current),
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
        ],
      ),
    );
  }

  /// Crop mode's page: the whole photo (unrotated: the corners are the
  /// photo's), as large as fits with the buttons under it.
  Widget _cropView(ScannedPage page, DetectedQuad draft) {
    final t = context.tokens;
    return LayoutBuilder(
      builder: (context, box) {
        // DkCropOverlay is as tall as its width allows, plus its 44 dp
        // handle margin and the button row: fit the width to the height.
        // ponytail: the button row's 56 is estimated; at large text it wraps.
        const chrome = 44.0 + 56;
        final pad = t.space.l;
        final width = ((box.maxHeight - 2 * pad - chrome) * _aspect + 44).clamp(
          0.0,
          box.maxWidth - 2 * pad,
        );
        return Padding(
          padding: EdgeInsets.all(pad),
          child: Center(
            child: SizedBox(
              width: width,
              child: DkCropOverlay(
                image: Image(
                  image: ref.read(scanStoreProvider).image(page.path),
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
                aspectRatio: _aspect,
                quad: draft,
                snapTo: page.quad,
                onChanged: (q) => setState(() => _draft = q),
                onAuto: page.quad == null
                    ? null
                    : () => setState(() => _draft = page.quad),
                onFullPage: () => setState(() => _draft = ScannedPage.fullPage),
                onReset: () => setState(() => _draft = _cropStart),
              ),
            ),
          ),
        );
      },
    );
  }
}
