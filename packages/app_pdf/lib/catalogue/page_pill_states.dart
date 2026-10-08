import 'package:flutter/material.dart';

import '../components/dk_page_pill.dart';
import '../theme/dk_tokens.dart';

Widget _wrap(BuildContext context, List<Widget> children) => Wrap(
  spacing: context.tokens.space.s,
  runSpacing: context.tokens.space.s,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: children,
);

/// DkPagePill over a page-coloured background, as in the viewer.
class DkPagePillGallery extends StatelessWidget {
  const DkPagePillGallery({super.key});

  @override
  Widget build(BuildContext context) => Container(
    color: context.tokens.color.surfaceSunken,
    padding: EdgeInsets.all(context.tokens.space.l),
    child: _wrap(context, const [
      DkPagePill(page: 3, count: 12),
      DkPagePill(page: 128, count: 300),
    ]),
  );
}
