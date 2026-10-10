import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../theme/dk_tokens.dart';

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
    this.onLink,
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

  /// A link to a web address was tapped (V1 asks first, DK-1088); a link to
  /// a page in the file jumps there. Null: links do nothing.
  final ValueChanged<Uri>? onLink;

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
    return PdfViewer.file(
      widget.path,
      controller: _controller,
      initialPageNumber: widget.initialPage,
      passwordProvider: widget.password == null ? null : () => widget.password,
      params: PdfViewerParams(
        backgroundColor: t.color.surfaceSunken,
        margin: DkPdfCanvas.gap,
        // Light shows the shadow; dark has none (elevation is a lighter
        // surface there), which the outline makes up for.
        pageDropShadow: shadows.isEmpty ? null : shadows.first,
        pageBackgroundPaintCallbacks: [
          (canvas, rect, _) =>
              canvas.drawRect(rect, Paint()..color = t.color.pageWhite),
        ],
        pagePaintCallbacks: [
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
          if (details.type != PdfViewerGeneralTapType.doubleTap) return false;
          _fitWidth(controller, details.documentPosition);
          return true;
        },
        onPageChanged: widget.onPageChanged,
        onViewerReady: widget.onReady == null
            ? null
            : (_, _) => widget.onReady!(),
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
