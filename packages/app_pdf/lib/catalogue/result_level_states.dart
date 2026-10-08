import 'package:flutter/material.dart';

import '../components/dk_level_card.dart';
import '../components/dk_result_card.dart';
import '../theme/dk_tokens.dart';

const _levels = [
  (0, (title: 'Light', estimate: '≈ 6.1 MB', description: 'Best quality')),
  (
    1,
    (
      title: 'Recommended',
      estimate: '≈ 1.9 MB',
      description: 'Good for email and uploads',
    ),
  ),
  (2, (title: 'Strong', estimate: '≈ 0.8 MB', description: 'Smallest file')),
];

/// DkResultCard (done, partial) and DkLevelCards with the middle selected.
class DkResultLevelGallery extends StatelessWidget {
  const DkResultLevelGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: t.space.l,
      children: [
        const DkResultCard(
          headline: '1.9 MB',
          delta: '(−77 %)',
          sub: 'From 8.4 MB · 12 pages',
        ),
        const DkResultCard(
          headline: '10 of 12 pages',
          sub: 'Page 7 and 9 are too blurry to read',
          partial: true,
        ),
        DkLevelCards<int>(levels: _levels, selected: 1, onChanged: (_) {}),
      ],
    );
  }
}
