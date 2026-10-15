import 'package:flutter/material.dart';

import '../../theme/dk_layout.dart';
import '../../theme/dk_tokens.dart';

/// T2's and T3's layout by width (UI spec §24; DK-0388), as the Scaffold's
/// body: a phone shows [content]; a small tablet the same in a 640-wide
/// centred column; a large tablet (840 and wider) [content] and [actions] in
/// a 480-wide column beside the [preview] pane, titled [previewTitle]. On a
/// phone and a small tablet the actions stay the Scaffold's bottom bar
/// ([bottom]), so toasts float above them.
class ToolLayout extends StatelessWidget {
  const ToolLayout({
    super.key,
    required this.content,
    required this.actions,
    this.preview,
    this.previewTitle,
  });

  /// The scrolling column: the input or the result, the options.
  final Widget content;

  /// The action bar (with the mini job bar above it).
  final Widget actions;

  /// The live preview: the input with the options applied (T2) or the result
  /// (T3); null: none.
  final Widget? preview;
  final String? previewTitle;

  /// The column beside the preview, and the widest a small tablet's.
  static const columnWidth = 480.0, maxWidth = 640.0;

  static bool _beside(BuildContext context, bool preview) =>
      preview &&
      DkGrid.forWidth(MediaQuery.sizeOf(context).width) == DkGrid.largeTablet;

  /// The Scaffold's bottom bar: [actions], 640 wide on a small tablet; null
  /// on a large one, where they sit in the column.
  static Widget? bottom(
    BuildContext context,
    Widget actions, {
    required bool preview,
  }) {
    if (_beside(context, preview)) return null;
    if (DkGrid.forWidth(MediaQuery.sizeOf(context).width) == DkGrid.phone) {
      return actions;
    }
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_beside(context, preview != null)) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: columnWidth,
            child: Column(
              children: [
                Expanded(child: content),
                actions,
              ],
            ),
          ),
          VerticalDivider(width: 1, color: t.color.outline),
          Expanded(
            child: ColoredBox(
              color: t.color.surfaceSunken,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (previewTitle != null)
                    Padding(
                      padding: EdgeInsets.all(t.space.l),
                      child: Semantics(
                        container: true,
                        header: true,
                        child: Text(
                          previewTitle!,
                          style: t.text.titleS.copyWith(
                            color: t.color.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  Expanded(child: preview!),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (DkGrid.forWidth(MediaQuery.sizeOf(context).width) != DkGrid.phone) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: content,
        ),
      );
    }
    return content;
  }
}
