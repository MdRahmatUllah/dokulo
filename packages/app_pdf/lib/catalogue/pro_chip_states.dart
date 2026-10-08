import 'package:flutter/material.dart';

import '../components/dk_chip.dart';
import '../components/dk_pro_badge.dart';
import '../theme/dk_tokens.dart';

Widget _wrap(BuildContext context, List<Widget> children) => Wrap(
  spacing: context.tokens.space.s,
  runSpacing: context.tokens.space.s,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: children,
);

/// DkProBadge (regular, small) and DkChip (filter off/on/disabled, choice
/// off/on).
class DkProBadgeChipGallery extends StatelessWidget {
  const DkProBadgeChipGallery({super.key});

  @override
  Widget build(BuildContext context) {
    void any(bool _) {}
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: context.tokens.space.m,
      children: [
        _wrap(context, const [DkProBadge(), DkProBadge(small: true)]),
        _wrap(context, [
          DkChip(label: 'Scans', selected: false, onSelected: any),
          DkChip(label: 'PDFs', selected: true, onSelected: any),
          const DkChip(label: 'Images', selected: false, onSelected: null),
          DkChip(
            label: 'Pressed',
            selected: false,
            onSelected: any,
            showPressed: true,
          ),
          DkChip(
            label: 'Focused',
            selected: false,
            onSelected: any,
            showFocused: true,
          ),
        ]),
        _wrap(context, [
          DkChip(
            label: 'All',
            selected: true,
            onSelected: any,
            kind: DkChipKind.choice,
          ),
          DkChip(
            label: 'Organize',
            selected: false,
            onSelected: any,
            kind: DkChipKind.choice,
          ),
        ]),
      ],
    );
  }
}
