import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';
import 'dk_button.dart';
import 'dk_illustration.dart';

/// What a screen shows when it has nothing yet (UI spec §11.7; DK-0196): a
/// centred column of the 120 illustration, 24, the title in `titleM`, 8,
/// the body in `bodyM` `textSecondary` (at most 280 wide), 24, the primary
/// button, 12, an optional secondary button. The illustration is decorative:
/// the title and body say it.
class DkEmptyState extends StatelessWidget {
  const DkEmptyState({
    super.key,
    required this.illustration,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
    this.secondaryAction,
    this.onSecondaryAction,
  });

  final DkIllustrations illustration;
  final String title;
  final String body;

  /// "Scan a document", "Move files here".
  final String? action;
  final VoidCallback? onAction;
  final String? secondaryAction;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(t.space.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ILL-04.. are 120 × 120; onboarding ones scale down to 120 high.
            DkIllustration(illustration, scale: 120 / illustration.height),
            SizedBox(height: t.space.xl),
            Text(
              title,
              style: t.text.titleM.copyWith(color: t.color.textPrimary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: t.space.s),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                body,
                style: t.text.bodyM.copyWith(color: t.color.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            if (action != null) ...[
              SizedBox(height: t.space.xl),
              DkButton(label: action!, onPressed: onAction),
            ],
            if (secondaryAction != null) ...[
              SizedBox(height: t.space.m),
              DkButton(
                label: secondaryAction!,
                onPressed: onSecondaryAction,
                variant: DkButtonVariant.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
