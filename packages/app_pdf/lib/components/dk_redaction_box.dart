import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_box_frame.dart';

/// A black-out box on a page (UI spec §11.5; DK-0160). Editing: black at
/// 85 % with a 1 dp white inner line and the category tag above ("IBAN");
/// selected, it moves, resizes by its corners and has a delete ×.
/// [applied]: solid black, no tag, as the output file shows it.
///
/// A [Positioned] for the page's [Stack] (see [DkBoxFrame]). Black and white
/// are `color.redactBox` and `color.onCamera`: the same in both themes.
class DkRedactionBox extends StatelessWidget {
  const DkRedactionBox({
    super.key,
    required this.rect,
    required this.category,
    this.applied = false,
    this.selected = false,
    this.onChanged,
    this.onTap,
    this.onDelete,
  });

  final Rect rect;

  /// The detector's name, already translated ("IBAN", "Name").
  final String category;
  final bool applied;
  final bool selected;
  final ValueChanged<Rect>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.color;
    if (applied) {
      return Positioned.fromRect(
        rect: rect,
        child: ExcludeSemantics(child: ColoredBox(color: c.redactBox)),
      );
    }
    final l10n = AppLocalizations.of(context);
    final text = context.tokens.text.caption.copyWith(color: c.onCamera);
    return DkBoxFrame(
      rect: rect,
      selected: selected,
      onChanged: onChanged,
      onTap: onTap,
      onDelete: onDelete,
      deleteLabel: l10n.redact_box_remove,
      semanticsLabel: l10n.redact_box_label(category),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.redactBox.withValues(alpha: 0.85),
              border: Border.all(color: c.redactBox),
            ),
            child: Padding(
              padding: const EdgeInsets.all(1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: c.onCamera),
                ),
              ),
            ),
          ),
          // The tag sits on the box's top edge, 2 dp above it.
          Positioned(
            left: 0,
            top: 0,
            child: FractionalTranslation(
              translation: const Offset(0, -1),
              child: Padding(
                padding: EdgeInsets.only(bottom: context.tokens.space.xxs),
                child: ExcludeSemantics(
                  child: ColoredBox(
                    color: c.redactBox,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.tokens.space.xs,
                      ),
                      child: Text(category, style: text, maxLines: 1),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
