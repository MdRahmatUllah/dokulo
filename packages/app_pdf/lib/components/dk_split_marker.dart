import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';

/// A cut between two documents in Smart Split's review (UI spec §11.8,
/// §21; DK-0216): a 2 dp primary line across, the scissor (`content_cut`
/// 16) in a 24 circle, and the optional [reason] tag (`caption` on a
/// `primaryContainer` pill: "New letterhead"). Tapping it removes the cut;
/// the row is a 48 dp target.
class DkSplitMarker extends StatelessWidget {
  const DkSplitMarker({super.key, this.reason, this.onRemove});

  /// Why the AI cut here, already translated; null for a cut the user made.
  final String? reason;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final line = Expanded(child: Container(height: 2, color: c.primary));
    return Semantics(
      button: onRemove != null,
      label: [AppLocalizations.of(context).split_remove, ?reason].join(', '),
      // The children are excluded, the tap with them: give it back.
      excludeSemantics: true,
      onTap: onRemove,
      child: InkWell(
        onTap: onRemove,
        overlayColor: WidgetStatePropertyAll(t.state.pressed),
        splashFactory: NoSplash.splashFactory,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: LayoutBuilder(
            builder: (context, box) => Row(
              spacing: t.space.s,
              children: [
                line,
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.primary, width: 2),
                  ),
                  child: DkIcon(
                    DkIcons.cut,
                    size: DkIconSize.s,
                    color: c.primary,
                  ),
                ),
                // The reason keeps its width; only when the row runs out (a
                // long one at 200 %) it wraps, leaving 16 of line each side.
                if (reason != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: box.maxWidth - 24 - 4 * t.space.s - 32,
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: t.space.s,
                        vertical: t.space.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: c.primaryContainer,
                        borderRadius: BorderRadius.circular(t.radius.pill),
                      ),
                      child: Text(
                        reason!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.text.caption.copyWith(
                          color: c.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                line,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The gap between two pages in a Smart Split strip (DK-0216): tapping it
/// cuts there. It shows nothing until pressed; screen readers hear "Split
/// here". 24 wide, as tall as the pages: the strip's spacing sets its
/// width, so the screen keeps the pages beside it inert.
class DkSplitGap extends StatelessWidget {
  const DkSplitGap({super.key, required this.height, required this.onSplit});

  final double height;
  final VoidCallback onSplit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).split_add,
      child: InkWell(
        onTap: onSplit,
        borderRadius: BorderRadius.circular(t.radius.xs),
        overlayColor: WidgetStatePropertyAll(t.state.pressed),
        splashFactory: NoSplash.splashFactory,
        // 48 wide, the touch minimum; the export's gap is 22, which only
        // spreads the strip a little (it scrolls).
        child: SizedBox(width: kMinInteractiveDimension, height: height),
      ),
    );
  }
}
