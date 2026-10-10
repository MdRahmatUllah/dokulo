import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../theme/dk_tokens.dart';
import 'dk_editor_bars.dart';
import 'dk_pdf_search.dart';

/// The viewer's canvas (V1, UI spec §17.1 region 2; DK-0293): pdfrx's
/// [PdfViewer] on PDFium, pages in one continuous vertical scroll at fit
/// width, pinch to zoom, double tap to fit the tapped page's width again,
/// rendered progressively (pdfrx draws a quick low-resolution pass, then the
/// sharp one). PDFium runs on pdfrx's worker, never on the UI isolate.
///
/// The canvas is `color.surfaceSunken`; each page is `color.pageWhite` with a
/// 1 dp `color.outline` and `elevation.raised`; 8 between pages and at the
/// sides. Give a [controller] to jump to a page
/// (`controller.goToPage(pageNumber: n)`, 1-based).
class DkPdfCanvas extends StatefulWidget {
  const DkPdfCanvas({
    super.key,
    required this.path,
    this.password,
    this.controller,
    this.initialPage = 1,
    this.onPageChanged,
    this.onReady,
    this.onTap,
    this.onScrollStart,
    this.onLink,
    this.night = false,
    this.markup,
    this.onMarkup,
    this.search,
  });

  final String path;

  /// For a locked PDF the user unlocked.
  final String? password;
  final PdfViewerController? controller;

  /// 1-based, as pdfrx counts.
  final int initialPage;

  /// The page mostly in view (1-based), for the page pill.
  final ValueChanged<int?>? onPageChanged;
  final VoidCallback? onReady;

  /// A single tap on the pages (V1 shows or hides its chrome, DK-0294).
  final VoidCallback? onTap;

  /// The user started to scroll or zoom.
  final VoidCallback? onScrollStart;

  /// A link to a web address was tapped (V1 asks first, DK-1088); a link to
  /// a page in the file jumps there. Null: links do nothing.
  final ValueChanged<Uri>? onLink;

  /// Selecting text (UI spec §17.1 Text selected; DK-1092): the selection
  /// in `color.primary` at 25 %, primary handles, and DkMarkupBar beside it
  /// with these actions; Copy copies. Null: no selection.
  final List<DkMarkupAction>? markup;

  /// Highlight, Underline or Strike on the selection (DK-0321): the
  /// selected text as one box per line on each page it spans (page space,
  /// origin bottom-left), for the annotations. The selection then clears.
  final void Function(DkMarkupAction action, List<SelectionLines> lines)?
  onMarkup;

  /// Text search (DK-1093): the matches in `markup.yellow` at 60 %, the
  /// current one outlined 2 dp in `color.primary` (UI spec §17.1).
  final DkPdfSearch? search;

  /// Night mode (UI spec §17.1; DK-1089): the pages inverted, dark with
  /// light text, on `color.nightCanvas`.
  final bool night;

  /// Between pages and at the sides (§17.1).
  static const gap = 8.0;

  @override
  State<DkPdfCanvas> createState() => _DkPdfCanvasState();
}

class _DkPdfCanvasState extends State<DkPdfCanvas> {
  /// For in-file links when the screen gave no controller.
  late final _own = PdfViewerController();

  PdfViewerController get _controller => widget.controller ?? _own;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final shadows = t.elevation.raised;
    final onLink = widget.onLink;
    final viewer = PdfViewer.file(
      widget.path,
      controller: _controller,
      initialPageNumber: widget.initialPage,
      passwordProvider: widget.password == null ? null : () => widget.password,
      params: PdfViewerParams(
        // In night mode the whole viewer goes through [_night]: its
        // background is the colour that comes out as `color.nightCanvas`.
        backgroundColor: widget.night
            ? _invert(t.color.nightCanvas)
            : t.color.surfaceSunken,
        margin: DkPdfCanvas.gap,
        // Light shows the shadow; dark has none (elevation is a lighter
        // surface there), which the outline makes up for.
        pageDropShadow: shadows.isEmpty ? null : shadows.first,
        pageBackgroundPaintCallbacks: [
          (canvas, rect, _) =>
              canvas.drawRect(rect, Paint()..color = t.color.pageWhite),
        ],
        pagePaintCallbacks: [
          if (widget.search case final search?)
            (canvas, rect, page) {
              for (final (match, current) in search.on(page.pageNumber)) {
                final box = match.bounds
                    .toRect(page: page, scaledPageSize: rect.size)
                    .translate(rect.left, rect.top);
                canvas.drawRect(
                  box,
                  Paint()
                    ..color = const DkMarkup().yellow.withValues(alpha: 0.6),
                );
                if (current) {
                  canvas.drawRect(
                    box.inflate(1),
                    Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 2
                      ..color = t.color.primary,
                  );
                }
              }
            },
          (canvas, rect, _) => canvas.drawRect(
            rect.deflate(0.5),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = t.color.outline,
          ),
        ],
        // Fit width at first, and kept through rotation (landscape) and
        // resizes; on a wide screen the page stops growing at 1.3× and
        // centres.
        sizeDelegateProvider: const PdfViewerSizeDelegateProviderSmart(),
        onGeneralTap: (context, controller, details) {
          if (details.type == PdfViewerGeneralTapType.tap &&
              widget.onTap != null) {
            widget.onTap!();
            return false; // links and selection still see the tap
          }
          if (details.type != PdfViewerGeneralTapType.doubleTap) return false;
          _fitWidth(controller, details.documentPosition);
          return true;
        },
        onPageChanged: widget.onPageChanged,
        onInteractionStart: widget.onScrollStart == null
            ? null
            : (_) => widget.onScrollStart!(),
        // The search attaches once the viewer has its document.
        onViewerReady: (_, controller) {
          widget.search?.attach(controller);
          widget.onReady?.call();
        },
        textSelectionParams: PdfTextSelectionParams(
          enabled: widget.markup != null,
        ),
        buildContextMenu: widget.markup == null
            ? null
            : (context, params) {
                final d = params.textSelectionDelegate;
                if (params.contextMenuFor != PdfViewerPart.selectedText ||
                    !d.hasSelectedText) {
                  return null;
                }
                return DkMarkupBar(
                  actions: widget.markup!,
                  onAction: (action) async {
                    if (action == DkMarkupAction.copy) {
                      await d.copyTextSelection();
                    } else if (widget.onMarkup case final onMarkup?
                        when action != DkMarkupAction.ask) {
                      final lines = selectionLines(
                        await d.getSelectedTextRanges(),
                      );
                      await d.clearTextSelection();
                      onMarkup(action, lines);
                    }
                    params.dismissContextMenu();
                  },
                );
              },
        linkHandlerParams: onLink == null
            ? null
            : PdfLinkHandlerParams(
                onLinkTap: (link) {
                  if (link.url case final url?) {
                    onLink(url);
                  } else {
                    _controller.goToDest(link.dest);
                  }
                },
              ),
      ),
    );
    // The selection in `color.primary` at 25 %, its handles in primary
    // (§17.1): pdfrx reads them from the theme.
    final themed = Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: t.color.primary.withValues(alpha: 0.25),
          selectionHandleColor: t.color.primary,
        ),
      ),
      child: viewer,
    );
    return widget.night
        ? ColorFiltered(colorFilter: _night, child: themed)
        : themed;
  }

  /// Fits the page under [documentPosition] (or the current one) to the
  /// view's width.
  static void _fitWidth(
    PdfViewerController controller,
    Offset documentPosition,
  ) {
    final layouts = controller.layout.pageLayouts;
    final hit = layouts.indexWhere((r) => r.contains(documentPosition));
    final page = hit >= 0 ? hit + 1 : (controller.pageNumber ?? 1);
    controller.goTo(controller.calcMatrixFitWidthForPage(pageNumber: page));
  }
}

/// Night mode's filter: each colour inverted, then turned 180° in hue, so
/// white pages go dark and black text light while colours (a photo, a blue
/// link) keep roughly their hue.
// ponytail: one filter over the page; leaving images un-inverted (§17.1)
// needs PDFium's per-object rendering, worth it when someone reads photo
// books at night.
const _night = ColorFilter.matrix([
  // -(180° luminance-preserving hue rotation) + 255: inverted, hue kept.
  0.574, -1.43, -0.144, 0, 255, //
  -0.426, -0.43, -0.144, 0, 255,
  -0.426, -1.43, 0.856, 0, 255,
  0, 0, 0, 1, 0,
]);

/// The colour [_night] turns into [c]: the canvas around the pages. Near
/// grey, the hue turn barely moves it, so a plain inversion is enough.
Color _invert(Color c) =>
    Color.from(alpha: 1, red: 1 - c.r, green: 1 - c.g, blue: 1 - c.b);

/// The selected text on one page, one box per line (page space).
typedef SelectionLines = ({int page, List<Box> lines});

/// pdfrx's selection as lines per page: each range's characters grouped
/// into lines the way the redaction boxes are ([PdfRedactor.lineBoxes]).
List<SelectionLines> selectionLines(List<PdfPageTextRange> ranges) => [
  for (final r in ranges)
    (
      page: r.pageNumber - 1,
      lines: PdfRedactor.lineBoxes(
        [
          for (final c in r.pageText.charRects)
            (left: c.left, top: c.top, right: c.right, bottom: c.bottom),
        ],
        r.start,
        r.end,
      ),
    ),
];
