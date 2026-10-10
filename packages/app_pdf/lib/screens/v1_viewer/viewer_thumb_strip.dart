import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_page_thumb.dart';
import '../../theme/dk_tokens.dart';
import '../t2_tool/tool_options_providers.dart';

/// V1's thumbnail strip (UI spec §17.1 region 5; DK-1091): above the bottom
/// bar, 96 tall, `color.surface` at 94 %, the pages as 48 × 64 DkPageThumb
/// with their numbers; the [current] one ringed and kept in view; a tap
/// answers its page ([onPage], 1-based). Only the pages in view render.
class ViewerThumbStrip extends StatefulWidget {
  const ViewerThumbStrip({
    super.key,
    required this.path,
    required this.pageCount,
    required this.current,
    required this.onPage,
  });

  final String path;
  final int pageCount;

  /// 1-based.
  final int current;
  final ValueChanged<int> onPage;

  static const height = 96.0;
  static const _item = 48.0 + 8;

  @override
  State<ViewerThumbStrip> createState() => _ViewerThumbStripState();
}

class _ViewerThumbStripState extends State<ViewerThumbStrip> {
  late final _scroll = ScrollController(
    initialScrollOffset: _offsetOf(widget.current),
  );

  double _offsetOf(int page) =>
      ((page - 1) * ViewerThumbStrip._item).clamp(0, double.infinity);

  @override
  void didUpdateWidget(ViewerThumbStrip old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current && _scroll.hasClients) {
      final viewport = _scroll.position.viewportDimension;
      final left = (widget.current - 1) * ViewerThumbStrip._item;
      final o = _scroll.offset;
      // Only when the current page left the strip's view.
      if (left < o || left + ViewerThumbStrip._item > o + viewport) {
        _scroll.jumpTo(
          (left - viewport / 2 + ViewerThumbStrip._item / 2).clamp(
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
    return Container(
      height: ViewerThumbStrip.height,
      color: t.color.surface.withValues(alpha: 0.94),
      child: ListView.builder(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: t.space.m,
          vertical: t.space.xs,
        ),
        itemExtent: ViewerThumbStrip._item,
        itemCount: widget.pageCount,
        itemBuilder: (context, i) => Padding(
          padding: EdgeInsets.only(right: t.space.s),
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
    );
  }
}
