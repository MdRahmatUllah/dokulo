import 'package:flutter/material.dart';

import '../components/dk_ai_parts.dart';
import '../theme/dk_tokens.dart';

void _none() {}

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
