import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_button.dart';
import 'dk_icon.dart';
import 'dk_illustration.dart';
import 'dk_number_text.dart';

/// A job that went wrong (UI spec §20.2 Failure, §26): what the error
/// state shows.
class DkProgressError {
  const DkProgressError({
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
    this.code,
  });

  final String title, body;

  /// "Try again", "Choose another file".
  final String action;
  final VoidCallback onAction;

  /// "Code DK-0190" in monospace under the body (an unexpected failure).
  final String? code;
}

/// A long job's progress (UI spec §11.7, §20.2; DK-0194): the content of a
/// small `showDkSheet`. A 40 tonal tool icon and the title ("Compressing
/// Mietvertrag.pdf") in `titleM`; a 6 dp pill bar with the percentage on
/// the right; "Page 18 of 40 · about 20 s left" in `bodyM`; Cancel
/// (secondary) and Keep working (primary). With [error] it shows ILL-20
/// (64), the error's title, body and one action instead.
///
/// Screen readers hear the progress in 25 % steps: the bar's value changes
/// only then, and it is a live region.
class DkProgressSheet extends StatelessWidget {
  const DkProgressSheet({
    super.key,
    required this.toolIcon,
    required this.title,
    required this.progress,
    required this.onCancel,
    required this.onKeepWorking,
    this.page,
    this.pageCount,
    this.timeLeft,
    this.error,
  });

  final IconData toolIcon;
  final String title;

  /// 0–1.
  final double progress;

  /// "Page [page] of [pageCount]", when the job goes page by page.
  final int? page, pageCount;

  /// "20 s", already formatted; null until there is an estimate.
  final String? timeLeft;
  final VoidCallback onCancel, onKeepWorking;
  final DkProgressError? error;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final failed = error;
    if (failed != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DkIllustration(
            DkIllustrations.genericError,
            scale: 64 / DkIllustrations.genericError.height,
          ),
          SizedBox(height: t.space.l),
          Text(
            failed.title,
            style: t.text.titleM.copyWith(color: c.textPrimary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: t.space.s),
          Text(
            failed.body,
            style: t.text.bodyM.copyWith(color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (failed.code case final code?) ...[
            SizedBox(height: t.space.xs),
            Text(
              code,
              style: t.text.mono.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
          SizedBox(height: t.space.xl),
          DkButton(
            label: failed.action,
            onPressed: failed.onAction,
            expand: true,
          ),
        ],
      );
    }

    final percent = (progress.clamp(0.0, 1.0) * 100).floor();
    final step = percent ~/ 25 * 25;
    final detail = [
      if (page != null && pageCount != null) l.progress_page(page!, pageCount!),
      if (timeLeft != null) l.progress_time_left(timeLeft!),
    ].join(' · ');
    final cancel = DkButton(
      label: l.common_cancel,
      onPressed: onCancel,
      variant: DkButtonVariant.secondary,
    );
    final keepWorking = DkButton(
      label: l.common_keep_working,
      onPressed: onKeepWorking,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: t.space.m,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.primaryContainer,
                borderRadius: BorderRadius.circular(t.radius.m),
              ),
              child: DkIcon(toolIcon, color: c.onPrimaryContainer),
            ),
            Expanded(
              child: Text(
                title,
                style: t.text.titleM.copyWith(color: c.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: t.space.l),
        Row(
          spacing: t.space.m,
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                label: title,
                value: '$step %',
                child: ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(t.radius.pill),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 6,
                      color: c.primary,
                      backgroundColor: c.surfaceSunken,
                    ),
                  ),
                ),
              ),
            ),
            ExcludeSemantics(
              child: DkNumberText(
                '$percent %',
                style: t.text.labelM.copyWith(color: c.textSecondary),
              ),
            ),
          ],
        ),
        if (detail.isNotEmpty) ...[
          SizedBox(height: t.space.s),
          DkNumberText(
            detail,
            style: t.text.bodyM.copyWith(color: c.textSecondary),
          ),
        ],
        SizedBox(height: t.space.xl),
        // Side by side; from 150 % text stacked, Keep working on top, so
        // neither label wraps past two lines (as DkActionBar does).
        if (MediaQuery.textScalerOf(context).scale(1) < 1.5)
          // Sized to their labels, from the start (tool-shell-progress);
          // on a narrow sheet the second wraps under the first.
          Wrap(
            spacing: t.space.s,
            runSpacing: t.space.s,
            children: [cancel, keepWorking],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: t.space.s,
            children: [keepWorking, cancel],
          ),
      ],
    );
  }
}
