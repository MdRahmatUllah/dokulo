import 'package:flutter/material.dart';

import '../components/dk_logo.dart';
import '../theme/dk_tokens.dart';

/// DkLogo: the symbol at its sizes in use (72 launch, 56 app lock, 24 Me
/// footer, 16 the smallest), the wordmark (32, About), the lockup, and
/// monochrome on primary (the app icon's look).
class LogoStates extends StatelessWidget {
  const LogoStates({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DkLogo.symbol(),
            DkLogo.symbol(size: 56),
            DkLogo.symbol(size: 24),
            DkLogo.symbol(size: 16),
          ],
        ),
        const DkLogo.wordmark(),
        const DkLogo.lockup(),
        Container(
          color: t.color.primary,
          child: DkLogo.symbol(color: t.color.onPrimary),
        ),
      ],
    );
  }
}
