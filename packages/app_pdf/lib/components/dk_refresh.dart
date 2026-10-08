import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';

/// Pull to refresh (DK-0228; UI spec §12.8), only on Home and Files, where
/// it re-scans the app folder: pulling [child] (a scrollable) down runs
/// [onRefresh] under the platform's own spinner (iOS's petals, Android's
/// ring), in `color.primary` on `color.surfaceRaised`.
///
/// Pulling is a gesture only, so screen readers get a "Refresh" action that
/// does the same.
class DkRefresh extends StatelessWidget {
  const DkRefresh({super.key, required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(
          label: AppLocalizations.of(context).common_refresh,
        ): onRefresh,
      },
      child: RefreshIndicator.adaptive(
        onRefresh: onRefresh,
        color: t.color.primary,
        backgroundColor: t.color.surfaceRaised,
        child: child,
      ),
    );
  }
}
