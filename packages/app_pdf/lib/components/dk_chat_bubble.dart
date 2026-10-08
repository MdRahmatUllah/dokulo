import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';
import 'dk_page_chip.dart';

/// Who said it.
enum DkChatRole { user, ai }

/// One message in Ask this PDF (UI spec §11.8; DK-0210).
/// - **User:** right-aligned, `primaryContainer`, `radius.m` with a 4 dp
///   bottom-right corner, `bodyL`.
/// - **AI:** left-aligned on `surface` with a 1 dp outline. `**bold**` in
///   [text] is drawn bold (key numbers and dates), and [pages] follow as
///   DkPageChips. While [streaming], a 2 × 16 primary caret blinks at the
///   end (still with Reduce Motion).
///
/// At most 85 % of the width, so the conversation reads as two sides.
class DkChatBubble extends StatelessWidget {
  const DkChatBubble({
    super.key,
    required this.role,
    required this.text,
    this.pages = const [],
    this.onPage,
    this.streaming = false,
  });

  final DkChatRole role;
  final String text;

  /// The pages the answer comes from (1-based).
  final List<int> pages;
  final ValueChanged<int>? onPage;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final user = role == DkChatRole.user;
    final r = Radius.circular(t.radius.m);
    final style = t.text.bodyL.copyWith(
      color: user ? c.onPrimaryContainer : c.textPrimary,
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: t.space.s,
      children: [
        Text.rich(
          TextSpan(
            style: style,
            children: [
              ..._bolded(text, style),
              if (streaming)
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: ExcludeSemantics(child: _Caret()),
                ),
            ],
          ),
        ),
        if (pages.isNotEmpty)
          Wrap(
            spacing: t.space.xs,
            children: [
              for (final p in pages)
                DkPageChip(page: p, onTap: () => onPage?.call(p)),
            ],
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) => Align(
        alignment: user ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: box.maxWidth * 0.85),
          child: Container(
            padding: EdgeInsets.all(t.space.m),
            decoration: BoxDecoration(
              color: user ? c.primaryContainer : c.surface,
              border: user ? null : Border.all(color: c.outline),
              borderRadius: BorderRadius.only(
                topLeft: r,
                topRight: r,
                bottomLeft: r,
                bottomRight: user ? const Radius.circular(4) : r,
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  /// [text] with `**…**` drawn bold (the markers dropped).
  static List<InlineSpan> _bolded(String text, TextStyle style) {
    final parts = text.split('**');
    return [
      for (final (i, part) in parts.indexed)
        if (part.isNotEmpty)
          TextSpan(
            text: part,
            style: i.isOdd
                ? const TextStyle(fontWeight: FontWeight.w700)
                : null,
          ),
    ];
  }
}

/// The streaming caret: 2 × 16, primary, blinking every 500 ms; still with
/// Reduce Motion.
class _Caret extends StatefulWidget {
  const _Caret();

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> {
  Timer? _blink;
  bool _on = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _blink?.cancel();
    // Still with Reduce Motion: and visible, wherever the blink was.
    if (context.reduceMotion) {
      _on = true;
    } else {
      _blink = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => setState(() => _on = !_on),
      );
    }
  }

  @override
  void dispose() {
    _blink?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Opacity(
      opacity: _on ? 1 : 0,
      child: Container(
        width: 2,
        height: 16,
        color: context.tokens.color.primary,
      ),
    ),
  );
}
