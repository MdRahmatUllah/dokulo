import 'package:flutter/material.dart';

import '../components/dk_empty_state.dart';
import '../components/dk_illustration.dart';
import '../components/dk_sheet.dart';
import '../l10n/app_localizations.dart';

/// "AI isn't available on this phone" (UI spec §20, Device not eligible):
/// ILL-13, how much memory the AI needs and how much this phone has, OK.
/// V1's AI button and T1's AI tools open it (DK-0256).
Future<void> showAiNotEligible(
  BuildContext context, {
  required int needGb,
  required int haveGb,
}) {
  final l = AppLocalizations.of(context);
  return showDkSheet<void>(
    context,
    body: Builder(
      builder: (sheet) => DkEmptyState(
        illustration: DkIllustrations.deviceNotEligible,
        illustrationSize: 80,
        title: l.ai_not_eligible_title,
        body: l.ai_not_eligible_body(needGb, haveGb),
        action: l.common_ok,
        onAction: () => Navigator.pop(sheet),
      ),
    ),
  );
}

/// A phone's memory in whole GB, as phones are sold: 3.6 GiB reads "4".
int memoryGb(int bytes) => (bytes / (1 << 30)).round();
