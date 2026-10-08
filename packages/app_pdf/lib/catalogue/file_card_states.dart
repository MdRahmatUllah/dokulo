import 'package:flutter/material.dart';

import '../components/dk_file_card.dart';
import '../theme/dk_tokens.dart';

/// A stand-in rendered page: white, a title bar and text lines.
class _Page extends StatelessWidget {
  const _Page();

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.color;
    return Container(
      width: 60,
      height: 85,
      color: c.pageWhite,
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Container(width: 30, height: 4, color: c.iconSecondary),
          for (var i = 0; i < 6; i++) Container(height: 2, color: c.outline),
        ],
      ),
    );
  }
}

const _name = 'Mietvertrag_Musterstraße_12_2026.pdf';
const _meta = '2.4 MB · 12 pages · Today 14:32';

/// DkFileCard: list rows (default, loading, pressed, selected, unselected,
/// locked, processing, encrypted, HTML), grid cards and a compact card.
class DkFileCardGallery extends StatelessWidget {
  const DkFileCardGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    void tap() {}
    const page = _Page();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DkFileCard(
          name: _name,
          meta: _meta,
          thumbnail: page,
          onTap: tap,
          onMore: tap,
        ),
        DkFileCard(name: 'Loading.pdf', meta: _meta, onTap: tap, onMore: tap),
        DkFileCard(
          name: 'Pressed.pdf',
          meta: _meta,
          thumbnail: page,
          onTap: tap,
          showPressed: true,
        ),
        DkFileCard(
          name: 'Selected.pdf',
          meta: _meta,
          thumbnail: page,
          onTap: tap,
          selected: true,
        ),
        DkFileCard(
          name: 'Not selected.pdf',
          meta: _meta,
          thumbnail: page,
          onTap: tap,
          selected: false,
        ),
        DkFileCard(
          name: 'Locked.pdf',
          meta: _meta,
          thumbnail: page,
          onTap: tap,
          locked: true,
        ),
        DkFileCard(
          name: 'Compressing.pdf',
          meta: _meta,
          thumbnail: page,
          onTap: tap,
          progress: 0.4,
        ),
        DkFileCard(
          name: 'Encrypted.pdf',
          meta: _meta,
          thumbnail: page,
          onTap: tap,
          encrypted: true,
        ),
        DkFileCard(
          name: 'Article.html',
          meta: '84 KB · Yesterday 09:10',
          kind: DkFileKind.html,
          onTap: tap,
        ),
        SizedBox(height: t.space.m),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: t.space.m,
          children: [
            Expanded(
              child: DkFileCard(
                name: _name,
                meta: _meta,
                thumbnail: page,
                variant: DkFileCardVariant.grid,
                onTap: tap,
                onMore: tap,
              ),
            ),
            Expanded(
              child: DkFileCard(
                name: 'Selected.pdf',
                meta: _meta,
                thumbnail: page,
                variant: DkFileCardVariant.grid,
                onTap: tap,
                selected: true,
              ),
            ),
            DkFileCard(
              name: _name,
              meta: _meta,
              thumbnail: page,
              variant: DkFileCardVariant.compact,
              onTap: tap,
            ),
          ],
        ),
      ],
    );
  }
}
