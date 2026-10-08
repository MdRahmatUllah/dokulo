import 'package:flutter/material.dart';

import '../components/dk_privacy_line.dart';
import '../components/dk_status_dot.dart';
import '../theme/dk_tokens.dart';

Widget _wrap(BuildContext context, List<Widget> children) => Wrap(
  spacing: context.tokens.space.s,
  runSpacing: context.tokens.space.s,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: children,
);

/// DkPrivacyLine (tool, Home) and DkStatusDot (new, unsaved, running).
class DkPrivacyStatusGallery extends StatelessWidget {
  const DkPrivacyStatusGallery({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: context.tokens.space.m,
    children: [
      const DkPrivacyLine(),
      const DkPrivacyLine(where: DkPrivacyContext.home),
      _wrap(context, const [
        DkStatusDot(DkStatus.fresh),
        DkStatusDot(DkStatus.unsaved),
        DkStatusDot(DkStatus.running),
      ]),
    ],
  );
}
