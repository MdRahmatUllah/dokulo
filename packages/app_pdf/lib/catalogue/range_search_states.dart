import 'package:flutter/material.dart';

import '../components/dk_text_field.dart';
import '../theme/dk_tokens.dart';

const _pages = 'Pages';
const _wrong = 'Page 40 doesn’t exist – this PDF has 32 pages.';
const _find = 'Search tools';

/// DkRangeField (empty, with an error) and DkSearchField (empty, typed).
class DkRangeSearchGallery extends StatefulWidget {
  const DkRangeSearchGallery({super.key});

  @override
  State<DkRangeSearchGallery> createState() => _DkRangeSearchGalleryState();
}

class _DkRangeSearchGalleryState extends State<DkRangeSearchGallery> {
  final _range = TextEditingController(text: '1–3, 40');
  final _query = TextEditingController(text: 'comp');

  @override
  void dispose() {
    _range.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: t.space.l,
      children: [
        DkRangeField(label: _pages, onPick: () {}),
        DkRangeField(
          label: _pages,
          controller: _range,
          error: _wrong,
          onPick: () {},
        ),
        const DkSearchField(hint: _find),
        DkSearchField(hint: _find, controller: _query),
      ],
    );
  }
}
