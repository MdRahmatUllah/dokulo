import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_button.dart';
import '../../components/dk_chip.dart';
import '../../components/dk_crop_overlay.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_page_tray.dart';
import '../../components/dk_slider.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../patterns/dk_confirmations.dart';
import '../../patterns/dk_undo.dart';
import '../../theme/dk_tokens.dart';
import '../s1_scanner/scan_session.dart';
import '../s1_scanner/scanner_quick_settings.dart';
import '../s1_scanner/scanner_settings.dart';
import 'save_sheet.dart';

/// S2, the scan's review (DK-0352; UI spec S2, design
/// `10-scanner/scanner-review-review`, `-reorder`):
///
/// - the bar: "Add pages" (back to the camera), "Review 6 pages", Save;
/// - the current page large on `color.surfaceSunken` (swipe between them)
///   with "3 of 6" under it;
/// - the edit row: Crop · Rotate · Filter · Retake · Delete. Rotate and
///   Delete act here (Rotate turns in 220 ms; Delete offers Undo, and the
///   last page asks "Discard this scan?" first, DK-0357/0358); Retake opens
///   the camera ([onRetake]);
/// - crop mode (DK-0353, `scanner-review-crop`): the uncropped photo in
///   DkCropOverlay (Auto · Full page · Reset, the magnifier while a corner
///   is dragged), Cancel / Apply under it. After Full page or a rotation, a
///   chip "Apply to all pages" does the same to every page;
/// - filter mode (DK-0354, `scanner-review-filter`): a strip of the five
///   filters under the edit row and Brightness / Contrast; after a change
///   the chips "Apply to all pages" · "Use as default" (a long press on a
///   filter is Use as default too). Applying to all offers Undo (DK-0355).
///   The preview is a colour matrix; the real filter runs when the scan is
///   saved (doc_vision's applyScanFilter);
/// - DkPageTray: tap to go to a page, drag to reorder, "+" to add pages.
///
/// The pages are [scanSessionProvider]'s, which keeps them on disk: an
/// unsaved scan is still here after the app was killed.
class S2Screen extends ConsumerStatefulWidget {
  const S2Screen({
    super.key,
    required this.onAddPages,
    required this.onDiscard,
    this.onSave,
    this.onRetake,
  });

  final VoidCallback onAddPages;

  /// The scan was discarded (its last page deleted): leave the scanner.
  final VoidCallback onDiscard;

  /// Save opens the Save sheet (DK-0359); this gets what it chose. Save is
  /// disabled until it is given.
  final ValueChanged<ScanSaveOptions>? onSave;

  /// The page's index; null hides nothing, but disables the button.
  final ValueChanged<int>? onRetake;

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

  /// The chip after Full page, a rotation or a filter change: does it to
  /// every page and returns the pages as they were (for Undo).
  Future<List<ScannedPage>> Function()? _applyAll;

  /// Filter mode is open; [_filterChanged]: show "Use as default".
  var _filtering = false, _filterChanged = false;

  /// The page Rotate was last tapped on: it turns into place.
  String? _turned;

  @override
  void initState() {
    super.initState();
    // After a kill: bring the unsaved scan back.
    ref.read(scanSessionProvider.notifier).restore();
    ref.read(scannerSettingsProvider.notifier).load();
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
      _filterChanged = false;
    });
    if (_pager.hasClients) _pager.jumpToPage(index);
  }

  void _crop(ScannedPage page) {
    setState(() {
      _draft = _cropStart = page.corners;
      _applyAll = null;
      _filtering = false;
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
    setState(() => _turned = ref.read(scanSessionProvider)[index].id);
    await session.rotate(index);
    final turns = ref.read(scanSessionProvider)[index].turns;
    if (mounted) {
      setState(() => _applyAll = () => session.applyToAll(turns: turns));
    }
  }

  /// A filter-mode change to the current page.
  Future<void> _setFilter(
    int index, {
    ScanFilterChoice? filter,
    double? brightness,
    double? contrast,
  }) async {
    final session = ref.read(scanSessionProvider.notifier);
    final page = ref
        .read(scanSessionProvider)[index]
        .copyWith(filter: filter, brightness: brightness, contrast: contrast);
    await session.update(index, page);
    if (!mounted) return;
    final chosen = page.filter ?? ref.read(scannerSettingsProvider).filter;
    setState(() {
      _filterChanged = true;
      _applyAll = () => session.applyToAll(
        filter: chosen,
        brightness: page.brightness,
        contrast: page.contrast,
      );
    });
  }

  Future<void> _useAsDefault(ScanFilterChoice filter) async {
    await ref.read(scannerSettingsProvider.notifier).setFilter(filter);
    if (mounted) setState(() => _filterChanged = false);
  }

  Future<void> _applyToAll() async {
    final apply = _applyAll!;
    final l = AppLocalizations.of(context);
    setState(() => _applyAll = null);
    final before = await apply();
    if (!mounted) return;
    await showDkUndo(
      context,
      DkUndo.applyToAll,
      l.toast_applied_all,
      onUndo: () => ref.read(scanSessionProvider.notifier).restoreAll(before),
    );
  }

  Future<void> _save() async {
    final store = ref.read(scanStoreProvider);
    final pages = ref.read(scanSessionProvider);
    final options = await showScanSaveSheet(
      context,
      pages: pages.length,
      photoBytes: pages.fold(0, (sum, p) => sum + store.length(p.path)),
      folders: ref.read(scanFoldersProvider),
      now: ref.read(scanClockProvider)(),
    );
    if (options != null) widget.onSave?.call(options);
  }

  Future<void> _delete() async {
    final session = ref.read(scanSessionProvider.notifier);
    final l = AppLocalizations.of(context);
    final index = _current;
    if (ref.read(scanSessionProvider).length == 1) {
      // The last page: the whole scan goes, so ask (no Undo for that).
      if (!await confirmDk(context, DkConfirmation.discardScan)) return;
      await session.clear();
      widget.onDiscard();
      return;
    }
    final page = await session.remove(index);
    final left = ref.read(scanSessionProvider).length;
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
    final defaultFilter = ref.watch(scannerSettingsProvider).filter;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget photo(ScannedPage p, BoxFit fit, {ScanFilterChoice? filter}) =>
        ColorFiltered(
          colorFilter: scanPreviewFilter(
            filter ?? p.filter ?? defaultFilter,
            brightness: p.brightness,
            contrast: p.contrast,
          ),
          child: Image(
            image: ref.read(scanStoreProvider).image(p.path),
            fit: fit,
            gaplessPlayback: true,
          ),
        );

    Widget pageImage(
      ScannedPage p, {
      BoxFit fit = BoxFit.contain,
      bool animate = false,
    }) {
      final page = RotatedBox(quarterTurns: p.turns, child: photo(p, fit));
      if (!animate) return page;
      // Rotate: the page turns into place over 220 ms (from where it was).
      return TweenAnimationBuilder<double>(
        key: ValueKey((p.id, p.turns)),
        tween: Tween(begin: -0.25, end: 0),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        builder: (context, turn, child) =>
            Transform.rotate(angle: turn * 2 * math.pi, child: child),
        child: page,
      );
    }

    Widget tool(
      IconData icon,
      String label,
      VoidCallback? onTap, {
      bool active = false,
    }) => Expanded(
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
                  DkIcon(icon, color: active ? c.primary : c.iconPrimary),
                  Text(
                    label,
                    style: t.text.caption.copyWith(
                      color: active ? c.primary : c.textPrimary,
                    ),
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
        onDone: pages.isEmpty || widget.onSave == null ? null : _save,
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
                              child: pageImage(
                                pages[i],
                                animate: pages[i].id == _turned,
                              ),
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
          if (draft == null && !_filtering && _applyAll != null) _chips(null),
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
                    pages.isEmpty
                        ? null
                        : () => setState(() {
                            _filtering = !_filtering;
                            _applyAll = null;
                            _filterChanged = false;
                          }),
                    active: _filtering,
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
            if (_filtering && pages.isNotEmpty)
              _filterPanel(pages[current], current, photo, defaultFilter),
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

  /// "Apply to all pages", and after a filter change "Use as default".
  Widget _chips(ScanFilterChoice? filter) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return ColoredBox(
      color: t.color.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(t.space.l, t.space.s, t.space.l, 0),
        child: Wrap(
          spacing: t.space.s,
          runSpacing: t.space.s,
          children: [
            if (_applyAll != null)
              DkChip(
                label: l.common_apply_all,
                selected: false,
                onSelected: (_) => _applyToAll(),
              ),
            if (filter != null && _filterChanged)
              DkChip(
                label: l.common_use_default,
                selected: false,
                onSelected: (_) => _useAsDefault(filter),
              ),
          ],
        ),
      ),
    );
  }

  /// Filter mode: the five filters as previews of the page (56 × 72, the
  /// chosen one ringed in 2 dp primary), Brightness and Contrast.
  Widget _filterPanel(
    ScannedPage page,
    int index,
    Widget Function(ScannedPage, BoxFit, {ScanFilterChoice? filter}) photo,
    ScanFilterChoice defaultFilter,
  ) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final chosen = page.filter ?? defaultFilter;
    String percent(double v) => '${(v * 200).round()}';
    return ColoredBox(
      color: c.surface,
      child: Padding(
        padding: EdgeInsets.only(top: t.space.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: t.space.l),
              child: Row(
                spacing: t.space.m,
                children: [
                  for (final f in ScanFilterChoice.values)
                    Semantics(
                      button: true,
                      selected: f == chosen,
                      label: f.label(l),
                      excludeSemantics: true,
                      onTap: () => _setFilter(index, filter: f),
                      onLongPress: () => _useAsDefault(f),
                      child: GestureDetector(
                        onTap: () => _setFilter(index, filter: f),
                        onLongPress: () => _useAsDefault(f),
                        child: Column(
                          spacing: t.space.xs,
                          children: [
                            Container(
                              width: 56,
                              height: 72,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: f == chosen
                                      ? c.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: RotatedBox(
                                quarterTurns: page.turns,
                                child: photo(page, BoxFit.cover, filter: f),
                              ),
                            ),
                            Text(
                              f.label(l),
                              style: t.text.caption.copyWith(
                                color: c.textPrimary,
                                fontWeight: f == chosen
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _chips(chosen),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space.l),
              child: Column(
                children: [
                  DkSlider(
                    title: l.scan_brightness,
                    value: page.brightness,
                    min: -0.5,
                    max: 0.5,
                    format: percent,
                    onChanged: (v) => _setFilter(index, brightness: v),
                  ),
                  DkSlider(
                    title: l.scan_contrast,
                    value: page.contrast,
                    min: -0.5,
                    max: 0.5,
                    format: percent,
                    onChanged: (v) => _setFilter(index, contrast: v),
                  ),
                ],
              ),
            ),
          ],
        ),
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

/// The filter's look in the review, as a colour matrix (the design's CSS
/// filters: greyscale, contrast around mid-grey), then the sliders as
/// doc_vision's applyScanFilter applies them on save: contrast scales
/// (`1 + contrast`), brightness adds `100 * brightness`. [brightness] and
/// [contrast] are the sliders, -0.5 to 0.5.
ColorFilter scanPreviewFilter(
  ScanFilterChoice filter, {
  double brightness = 0,
  double contrast = 0,
}) {
  final grey =
      filter == ScanFilterChoice.greyscale ||
      filter == ScanFilterChoice.blackWhite;
  final f = switch (filter) {
    ScanFilterChoice.blackWhite => 1.8,
    ScanFilterChoice.autoColour => 1.05,
    _ => 1.0,
  };
  final shift =
      128 * (1 - f) + (filter == ScanFilterChoice.removeShadows ? 12 : 0);
  final k = (1 + contrast) * f;
  final offset = (1 + contrast) * shift + 100 * brightness;
  // Rec. 709 luma for grey; the identity otherwise.
  List<double> row(int channel) => grey
      ? [0.2126 * k, 0.7152 * k, 0.0722 * k, 0, offset]
      : [for (var i = 0; i < 3; i++) i == channel ? k : 0.0, 0, offset];
  return ColorFilter.matrix([...row(0), ...row(1), ...row(2), 0, 0, 0, 1, 0]);
}
