import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';

/// A page as a thumbnail (UI spec §11.5; DK-0150): the page on
/// `color.pageWhite` with a 1 dp outline, its number below. Selected: a 2 dp
/// primary ring and a check circle; the same ring shows keyboard focus.
/// Loading ([page] null): a `color.surfaceSunken` block with the number.
///
/// The parent sets the width (3 columns in DkPageGrid, 56 in DkPageTray);
/// the page keeps [aspectRatio]. [page] is the rendered page: a `RawImage`
/// of doc_core's `ThumbnailCache` (rendered on PDFium's worker, cached by
/// file version, page and width), or an `Image.file` of a scan.
class DkPageThumb extends StatefulWidget {
  const DkPageThumb({
    super.key,
    required this.pageNumber,
    required this.pageCount,
    this.page,
    this.selected = false,
    this.quarterTurns = 0,
    this.aspectRatio = 3 / 4,
    this.showNumber = true,
    this.onTap,
    this.onLongPress,
  });

  /// 1-based.
  final int pageNumber;
  final int pageCount;
  final Widget? page;
  final bool selected;

  /// A rotation the user made but hasn't saved yet; the content turns with it.
  final int quarterTurns;
  final double aspectRatio;
  final bool showNumber;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<DkPageThumb> createState() => _DkPageThumbState();
}

class _DkPageThumbState extends State<DkPageThumb> {
  bool _pressed = false, _hovered = false, _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final radius = BorderRadius.circular(t.radius.xs);
    final number = '${widget.pageNumber}';
    final caption = t.text.caption.copyWith(color: c.textSecondary);

    final Widget page = widget.page == null
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: c.surfaceSunken,
              borderRadius: radius,
            ),
            child: Center(child: Text(number, style: caption)),
          )
        // UI spec §29.4: white pages, dimmed to 92 % in Dark against glare.
        : ColorFiltered(
            colorFilter: ColorFilter.matrix(
              _brightness(t.brightness == Brightness.dark ? 0.92 : 1),
            ),
            child: DecoratedBox(
              decoration: t
                  .surfaceAt(DkLevel.flat, radius: radius)
                  .copyWith(color: c.pageWhite),
              child: ClipRRect(
                borderRadius: radius,
                child: RotatedBox(
                  quarterTurns: widget.quarterTurns,
                  child: FittedBox(child: widget.page),
                ),
              ),
            ),
          );
    final overlay = _pressed
        ? t.state.pressed
        : _hovered
        ? t.state.hover
        : null;
    // The ring sits 2 dp outside the page, as in the design export.
    final gap = t.space.xxs;
    final ringWidth = t.selectionRing.width;

    return Semantics(
      container: true,
      button: widget.onTap != null,
      enabled: widget.onTap != null ? true : null,
      selected: widget.selected,
      label: AppLocalizations.of(context)
          .progress_page(widget.pageNumber, widget.pageCount),
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onHighlightChanged: (v) => setState(() => _pressed = v),
        onHover: (v) => setState(() => _hovered = v),
        onFocusChange: (v) => setState(() => _focused = v),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AspectRatio(aspectRatio: widget.aspectRatio, child: page),
                  if (overlay != null)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: overlay,
                          borderRadius: radius,
                        ),
                      ),
                    ),
                  if (widget.selected || _focused)
                    Positioned.fill(
                      left: -gap - ringWidth,
                      top: -gap - ringWidth,
                      right: -gap - ringWidth,
                      bottom: -gap - ringWidth,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.fromBorderSide(t.selectionRing),
                            borderRadius: BorderRadius.circular(
                              t.radius.xs + gap + ringWidth,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (widget.selected)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: c.primary,
                          shape: BoxShape.circle,
                        ),
                        child: DkIcon(
                          DkIcons.check,
                          size: DkIconSize.s,
                          color: c.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
              if (widget.showNumber) ...[
                SizedBox(height: t.space.xs),
                Text(number, style: caption, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static List<double> _brightness(double f) => [
    f, 0, 0, 0, 0, //
    0, f, 0, 0, 0, //
    0, 0, f, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}
