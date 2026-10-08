import 'package:flutter/material.dart';

import '../components/dk_chat_bubble.dart';
import '../components/dk_diff_row.dart';
import '../theme/dk_tokens.dart';

void _none() {}

/// DkChatBubble (DK-0210): a question, an answer with bold numbers and page
/// chips, and an answer still streaming.
class ChatStates extends StatelessWidget {
  const ChatStates({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ColoredBox(
      color: t.color.background,
      child: Padding(
        padding: EdgeInsets.all(t.space.l),
        child: Column(
          spacing: t.space.m,
          children: const [
            DkChatBubble(
              role: DkChatRole.user,
              text: 'When does the notice period end?',
            ),
            DkChatBubble(
              role: DkChatRole.ai,
              text:
                  'The notice period is **3 months**, so it ends on '
                  '**31 December 2026**.',
              pages: [3, 7],
            ),
            DkChatBubble(
              role: DkChatRole.ai,
              text: 'The deposit is **1,240 EUR**, paid',
              streaming: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// DkDiffRow (DK-0218): one row per kind of change.
class DiffStates extends StatelessWidget {
  const DiffStates({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.tokens.color.surface,
    child: const Column(
      children: [
        DkDiffRow(
          change: DkChange.added,
          excerpt: 'Pets are allowed with written consent.',
          page: 2,
          onTap: _none,
        ),
        DkDiffRow(
          change: DkChange.removed,
          excerpt: 'The rent includes a parking space in the courtyard.',
          page: 3,
          onTap: _none,
        ),
        DkDiffRow(
          change: DkChange.changed,
          excerpt: 'The rent is 1,240 EUR plus operating costs.',
          page: 1,
          onTap: _none,
        ),
      ],
    ),
  );
}
