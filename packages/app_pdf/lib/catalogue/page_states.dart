import 'package:flutter/material.dart';

import '../components/dk_page_grid.dart';
import '../components/dk_page_thumb.dart';
import '../components/dk_page_tray.dart';
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

/// DkPageTray's states (DK-0152): six pages with page 2 current and the "+"
/// tile, two of them still loading; then a read-only tray (no "+").
class PageTrayStates extends StatelessWidget {
  const PageTrayStates({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ColoredBox(
      color: t.color.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: t.space.s),
          DkPageTray(
            pageIds: const [1, 2, 3, 4, 5, 6],
            pageBuilder: (_, i) => i < 4 ? const CataloguePage() : null,
            current: 1,
            onSelect: (_) {},
            onReorder: (_, _) {},
            onAdd: () {},
          ),
          SizedBox(height: t.space.l),
          DkPageTray(
            pageIds: const [1, 2, 3],
            pageBuilder: (_, _) => const CataloguePage(),
            current: 0,
          ),
          SizedBox(height: t.space.s),
        ],
      ),
    );
  }
}

/// DkPageGrid (DK-0154): 9 pages, 3 columns, pages 2 and 5 selected, page 7
/// still loading. Live: tap selects, long-press and drag reorders, pinch
/// changes the columns.
class PageGridStates extends StatefulWidget {
  const PageGridStates({super.key, this.pageCount = 9});
  final int pageCount;

  @override
  State<PageGridStates> createState() => _PageGridStatesState();
}

class _PageGridStatesState extends State<PageGridStates> {
  late final ids = [for (var i = 1; i <= widget.pageCount; i++) i];
  final selected = {1, 4};

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.tokens.color.background,
    child: SizedBox(
      height: 560,
      child: DkPageGrid(
        pageIds: ids,
        pageBuilder: (_, i) => ids[i] == 7 ? null : const CataloguePage(),
        selected: selected,
        onTap: (i) => setState(
          () => selected.contains(i) ? selected.remove(i) : selected.add(i),
        ),
        onReorder: (from, to) =>
            setState(() => ids.insert(to, ids.removeAt(from))),
      ),
    ),
  );
}
