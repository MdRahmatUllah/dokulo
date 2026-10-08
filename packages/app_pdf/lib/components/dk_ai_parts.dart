import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';

/// A question to start with on Ask's empty state (UI spec §11.8; DK-0212):
/// a full-width outline chip, the `forum` 16 icon, `bodyM`, two lines at
/// most.
class DkSuggestionChip extends StatelessWidget {
  const DkSuggestionChip({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(t.radius.m);
    return Semantics(
      button: true,
      child: Material(
        type: MaterialType.transparency,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: t.color.outlineStrong),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          overlayColor: WidgetStatePropertyAll(t.state.pressed),
          splashFactory: NoSplash.splashFactory,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: t.space.m,
                vertical: t.space.s,
              ),
              child: Row(
                spacing: t.space.s,
                children: [
                  DkIcon(
                    DkIcons.forum,
                    size: DkIconSize.s,
                    color: t.color.iconSecondary,
                  ),
                  Expanded(
                    child: Text(
                      text,
                      style: t.text.bodyM.copyWith(color: t.color.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The line under AI answers and summaries (UI spec §11.8; DK-0214): "On
/// this phone · Gemma 4 E2B · AI can make mistakes", in `caption`
/// `textSecondary`, with the model that actually ran.
class DkAIFooter extends StatelessWidget {
  const DkAIFooter({super.key, required this.model});

  /// The model's display name ("Gemma 4 E2B").
  final String model;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      AppLocalizations.of(context).ai_footer(model),
      style: t.text.caption.copyWith(color: t.color.textSecondary),
    );
  }
}
