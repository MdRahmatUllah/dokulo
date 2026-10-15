import 'package:flutter/material.dart';

import '../components/dk_model_card.dart';
import '../theme/dk_tokens.dart';

/// DkModelCard in its four states: available, downloading, installed,
/// unavailable.
class DkModelCardGallery extends StatelessWidget {
  const DkModelCardGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    void tap() {}
    DkModelCard card(String name, String quality, DkModelState state) =>
        DkModelCard(
          name: name,
          quality: quality,
          role: 'Summaries and questions',
          facts: '1.3 GB · needs 3 GB memory',
          licence: 'Apache-2.0',
          onLicence: tap,
          state: state,
          best: quality == 'Best quality',
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: t.space.m,
      children: [
        card('Gemma 4 E2B', 'Best quality', DkModelAvailable(onDownload: tap)),
        card(
          'Gemma 3 1B',
          'Fast',
          DkModelDownloading(
            progress: 0.32,
            detail: '420 MB of 1.3 GB · Wi-Fi',
            onPause: tap,
          ),
        ),
        card('MiniLM', 'Small', DkModelInstalled(onDelete: tap)),
        card('Qwen 3 4B', 'Best quality', const DkModelUnavailable()),
      ],
    );
  }
}
