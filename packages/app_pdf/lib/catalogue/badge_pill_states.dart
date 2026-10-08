import 'package:flutter/material.dart';

import '../components/dk_count_badge.dart';
import '../components/dk_hint_pill.dart';
import '../theme/dk_tokens.dart';

/// DkCountBadge (1, 12, 128) and DkHintPill on the camera chrome (short,
/// long).
class DkBadgePillGallery extends StatelessWidget {
  const DkBadgePillGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: t.space.m,
      children: [
        Wrap(
          spacing: t.space.s,
          children: const [
            DkCountBadge(1),
            DkCountBadge(12),
            DkCountBadge(128),
          ],
        ),
        Container(
          color: t.color.cameraChrome,
          padding: EdgeInsets.all(t.space.s),
          child: Wrap(
            spacing: t.space.s,
            runSpacing: t.space.s,
            children: const [
              DkHintPill('Hold steady'),
              DkHintPill('Move closer to the document'),
            ],
          ),
        ),
      ],
    );
  }
}
