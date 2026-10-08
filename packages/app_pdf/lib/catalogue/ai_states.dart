import 'package:flutter/material.dart';

import '../components/dk_ai_parts.dart';
import '../components/dk_page_thumb.dart';
import '../components/dk_signature_card.dart';
import '../components/dk_split_marker.dart';
import '../theme/dk_tokens.dart';
import 'page_states.dart';

void _none() {}

/// DkSignatureCard (DK-0208): two saved signatures.
class SignatureCardStates extends StatelessWidget {
  const SignatureCardStates({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget ink(String name) => Text(
      name,
      style: t.text.titleL.copyWith(
        color: t.markup.ink,
        fontStyle: FontStyle.italic,
      ),
    );
    return ColoredBox(
      color: t.color.background,
      child: Padding(
        padding: EdgeInsets.all(t.space.l),
        child: Wrap(
          spacing: t.space.m,
          runSpacing: t.space.m,
          children: [
            DkSignatureCard(
              signature: ink('M. Mustermann'),
              onTap: _none,
              onDelete: _none,
            ),
            DkSignatureCard(signature: ink('MM'), onTap: _none),
          ],
        ),
      ),
    );
  }
}

/// DkSuggestionChip (DK-0212) and DkAIFooter (DK-0214): Ask's empty state.
class AskStates extends StatelessWidget {
  const AskStates({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ColoredBox(
      color: t.color.background,
      child: Padding(
        padding: EdgeInsets.all(t.space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: t.space.s,
          children: const [
            DkSuggestionChip(text: 'What is the total amount?', onTap: _none),
            DkSuggestionChip(
              text:
                  'When does the notice period end, and what do I have to '
                  'send, to whom, and by when?',
              onTap: _none,
            ),
            DkAIFooter(model: 'Gemma 4 E2B'),
          ],
        ),
      ),
    );
  }
}

/// DkSplitMarker and DkSplitGap (DK-0216): a group's pages with gaps to
/// cut at, then cuts with and without a reason.
class SplitStates extends StatelessWidget {
  const SplitStates({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget page(int n) => SizedBox(
      width: 38,
      child: DkPageThumb(
        pageNumber: n,
        pageCount: 5,
        page: const CataloguePage(),
        showNumber: false,
        aspectRatio: 38 / 50,
      ),
    );
    return ColoredBox(
      color: t.color.background,
      child: Padding(
        padding: EdgeInsets.all(t.space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                page(1),
                const DkSplitGap(height: 50, onSplit: _none),
                page(2),
                const DkSplitGap(height: 50, onSplit: _none),
                page(3),
              ],
            ),
            const DkSplitMarker(reason: 'New letterhead', onRemove: _none),
            const DkSplitMarker(onRemove: _none),
          ],
        ),
      ),
    );
  }
}
