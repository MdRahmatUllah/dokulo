import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_page_thumb.dart';
import '../../theme/dk_tokens.dart';
import '../t2_tool/tool_options_providers.dart';

/// V1's thumbnails, the [current] page ringed and kept in view; a tap
/// answers its page ([onPage], 1-based). Only the pages in view render.
///
/// - Horizontal: the phone's strip (UI spec §17.1 region 5; DK-1091) above
///   the bottom bar, 96 tall, `color.surface` at 94 % under a hairline, the
///   pages as 48 × 64 DkPageThumb with their numbers.
/// - Vertical: the tablet's sidebar (§17.4, `24-tablet/tablet-viewer-*`;
///   DK-0310), 120 wide on `color.surface` with a hairline on its right, the
///   pages 64 × 86.
class ViewerThumbStrip extends StatefulWidget {
  const ViewerThumbStrip({
    super.key,
    required this.path,
    required this.pageCount,
    required this.current,
    required this.onPage,
    this.axis = Axis.horizontal,
  });

  final String path;
  final int pageCount;

  /// 1-based.
  final int current;
  final ValueChanged<int> onPage;
  final Axis axis;

  /// The strip's height; the sidebar's width.
  static const height = 96.0, sidebarWidth = 120.0;

  @override
  State<ViewerThumbStrip> createState() => _ViewerThumbStripState();
}

class _ViewerThumbStripState extends State<ViewerThumbStrip> {
  bool get _vertical => widget.axis == Axis.vertical;

  /// One page's run along the axis: the thumb (and, down the sidebar, its
  /// number under it) and the gap.
  double get _item => _vertical ? 86 + 4 + 16 + 12 : 48 + 8;

  late final _scroll = ScrollController(
    initialScrollOffset: ((widget.current - 1) * _item).clamp(
      0,
      double.infinity,
    ),
  );

  @override
  void didUpdateWidget(ViewerThumbStrip old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current && _scroll.hasClients) {
      final viewport = _scroll.position.viewportDimension;
      final start = (widget.current - 1) * _item;
      final o = _scroll.offset;
      // Only when the current page left the strip's view.
      if (start < o || start + _item > o + viewport) {
        _scroll.jumpTo(
          (start - viewport / 2 + _item / 2).clamp(
            0,
            _scroll.position.maxScrollExtent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hairline = BorderSide(color: t.color.outline);
    return Container(
      width: _vertical ? ViewerThumbStrip.sidebarWidth : null,
      height: _vertical ? null : ViewerThumbStrip.height,
      decoration: BoxDecoration(
        color: _vertical
            ? t.color.surface
            : t.color.surface.withValues(alpha: 0.94),
        border: _vertical ? Border(right: hairline) : Border(top: hairline),
      ),
      child: ListView.builder(
        controller: _scroll,
        scrollDirection: widget.axis,
        padding: _vertical
            ? EdgeInsets.symmetric(vertical: t.space.m)
            : EdgeInsets.symmetric(horizontal: t.space.m),
        itemExtent: _item,
        itemCount: widget.pageCount,
        itemBuilder: (context, i) => Padding(
          padding: _vertical
              ? EdgeInsets.only(bottom: t.space.m)
              : EdgeInsets.only(right: t.space.s),
          child: Center(
            child: SizedBox(
              width: _vertical ? 64 : null,
              child: Consumer(
                builder: (context, ref, _) {
                  final image = ref
                      .watch(pdfThumbnailProvider(widget.path, page: i + 1))
                      .value;
                  return DkPageThumb(
                    pageNumber: i + 1,
                    pageCount: widget.pageCount,
                    page: image == null ? null : RawImage(image: image),
                    current: i + 1 == widget.current,
                    onTap: () => widget.onPage(i + 1),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
