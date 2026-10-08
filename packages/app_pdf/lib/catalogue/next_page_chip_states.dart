import 'package:flutter/material.dart';

import '../components/dk_next_chip.dart';
import '../components/dk_page_chip.dart';
import '../theme/dk_tokens.dart';

Widget _wrap(BuildContext context, List<Widget> children) => Wrap(
  spacing: context.tokens.space.s,
  runSpacing: context.tokens.space.s,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: children,
);

/// DkNextChip (three tools) and DkPageChip.
class DkNextPageChipGallery extends StatelessWidget {
  const DkNextPageChipGallery({super.key});

  @override
  Widget build(BuildContext context) {
    void tap() {}
    return _wrap(context, [
      DkNextChip(toolId: 'compress', onTap: tap),
      DkNextChip(toolId: 'pagenum', onTap: tap),
      DkNextChip(toolId: 'protect', onTap: tap),
      DkPageChip(page: 3, onTap: tap),
      DkPageChip(page: 12, onTap: tap),
    ]);
  }
}
