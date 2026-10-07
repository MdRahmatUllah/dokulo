import 'package:flutter/material.dart';

import '../components/dk_page_thumb.dart';
import '../theme/dk_tokens.dart';

/// A page as the design export draws it: a title bar and text lines, in a
/// document's own greys (pages look the same in both themes). Not symmetric,
/// so a rotation shows.
class CataloguePage extends StatelessWidget {
  const CataloguePage({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 60,
    height: 80,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 26, height: 4, color: const Color(0xFF8E9AAD)),
          const SizedBox(height: 6),
          for (var i = 0; i < 9; i++) ...[
            Container(height: 1.5, color: const Color(0xFFD3D8E0)),
            const SizedBox(height: 3.5),
          ],
        ],
      ),
    ),
  );
}

/// DkPageThumb's states (DK-0150): page, selected, loading, rotated, as in
/// the grid (96 wide), then the tray's 56 × 72.
class PageThumbStates extends StatelessWidget {
  const PageThumbStates({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget cell(Widget thumb) => SizedBox(width: 96, child: thumb);
    return ColoredBox(
      color: t.color.background,
      child: Padding(
        padding: EdgeInsets.all(t.space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: t.space.m,
              runSpacing: t.space.l,
              children: [
                cell(
                  const DkPageThumb(
                    pageNumber: 1,
                    pageCount: 12,
                    page: CataloguePage(),
                  ),
                ),
                cell(
                  const DkPageThumb(
                    pageNumber: 2,
                    pageCount: 12,
                    page: CataloguePage(),
                    selected: true,
                  ),
                ),
                cell(const DkPageThumb(pageNumber: 3, pageCount: 12)),
                cell(
                  const DkPageThumb(
                    pageNumber: 4,
                    pageCount: 12,
                    page: CataloguePage(),
                    quarterTurns: 1,
                  ),
                ),
              ],
            ),
            SizedBox(height: t.space.l),
            Row(
              children: [
                for (final (n, selected) in [(1, false), (2, true), (3, false)])
                  Padding(
                    padding: EdgeInsets.only(right: t.space.s),
                    child: SizedBox(
                      width: 56,
                      child: DkPageThumb(
                        pageNumber: n,
                        pageCount: 12,
                        page: const CataloguePage(),
                        selected: selected,
                        aspectRatio: 56 / 72,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
