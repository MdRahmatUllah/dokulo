import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_button.dart';
import 'dk_icon.dart';
import 'dk_number_text.dart';
import 'dk_tappable.dart';

/// Where a model stands on this phone (DkModelCard's action).
sealed class DkModelState {
  const DkModelState();
}

/// Not downloaded yet: a "Download" button.
class DkModelAvailable extends DkModelState {
  const DkModelAvailable({required this.onDownload});
  final VoidCallback onDownload;
}

/// Downloading: the pause button with a progress ring and the %, and a bar
/// under the facts with [detail] ("420 MB of 1.3 GB · Wi-Fi").
class DkModelDownloading extends DkModelState {
  const DkModelDownloading({
    required this.progress,
    required this.detail,
    required this.onPause,
  });

  /// 0–1.
  final double progress;
  final String detail;
  final VoidCallback onPause;
}

/// Installed: a "Delete" button (tertiary, danger).
class DkModelInstalled extends DkModelState {
  const DkModelInstalled({required this.onDelete});
  final VoidCallback onDelete;
}

/// The phone can't run it: "Not available on this phone".
class DkModelUnavailable extends DkModelState {
  const DkModelUnavailable();
}

/// An AI model in Me → Models (DK-0094; UI spec §11.2): the [name] in
/// `type.titleS` with its [quality] pill ("Best quality" / "Fast" /
/// "Small"; [best] tints it `color.success`, the others
/// `color.primaryContainer`, as the design draws it), the [role] line in
/// `type.bodyM` ("Summaries and questions"), the [facts] in `type.caption`
/// ("1.3 GB · needs 3 GB memory") followed by the [licence] as a link, and
/// the action for its [state] on the right.
class DkModelCard extends StatelessWidget {
  const DkModelCard({
    super.key,
    required this.name,
    required this.quality,
    required this.role,
    required this.facts,
    required this.licence,
    required this.onLicence,
    required this.state,
    this.best = false,
  });

  final String name, quality, role, facts, licence;

  /// The quality is the best one ("Best quality").
  final bool best;

  /// Opens the licence text.
  final VoidCallback onLicence;
  final DkModelState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final caption = t.text.caption.copyWith(color: c.textSecondary);

    final Widget action = switch (state) {
      DkModelAvailable(:final onDownload) => DkButton(
        label: l.common_download,
        onPressed: onDownload,
        variant: DkButtonVariant.secondary,
        size: DkButtonSize.compact,
      ),
      DkModelDownloading(:final progress, :final onPause) => Semantics(
        button: true,
        label: l.model_pause_progress((progress * 100).round()),
        excludeSemantics: true,
        onTap: onPause,
        child: DkTappable(
          onTap: onPause,
          radius: t.radius.s,
          builder: (context, pressed) => ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: t.space.s,
              children: [
                DkNumberText(
                  '${(progress * 100).round()} %',
                  style: t.text.labelM.copyWith(color: c.textSecondary),
                ),
                SizedBox.square(
                  dimension: 32,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 2,
                        color: c.primary,
                        backgroundColor: c.outline,
                      ),
                      DkIcon(
                        DkIcons.pause,
                        size: DkIconSize.s,
                        color: c.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      DkModelInstalled(:final onDelete) => DkButton(
        label: l.common_delete,
        onPressed: onDelete,
        variant: DkButtonVariant.tertiaryDanger,
        size: DkButtonSize.compact,
      ),
      DkModelUnavailable() => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120),
        child: Text(
          l.model_not_available,
          style: caption,
          textAlign: TextAlign.end,
        ),
      ),
    };
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: t.space.xxs,
      children: [
        Wrap(
          spacing: t.space.s,
          runSpacing: t.space.xxs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(name, style: t.text.titleS.copyWith(color: c.textPrimary)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: t.space.s,
                vertical: t.space.xxs,
              ),
              decoration: BoxDecoration(
                color: best ? c.successContainer : c.primaryContainer,
                borderRadius: BorderRadius.circular(t.radius.pill),
              ),
              child: Text(
                quality,
                style: t.text.labelM.copyWith(
                  color: best ? c.success : c.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        Text(role, style: t.text.bodyM.copyWith(color: c.textPrimary)),
        Wrap(
          children: [
            Text('$facts · ', style: caption),
            Semantics(
              link: true,
              label: licence,
              excludeSemantics: true,
              onTap: onLicence,
              child: DkTappable(
                onTap: onLicence,
                radius: t.radius.xs,
                builder: (context, pressed) => Text(
                  licence,
                  style: caption.copyWith(
                    color: c.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: c.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    // At large text the action goes under the details, at the right.
    final below = MediaQuery.textScalerOf(context).scale(10) >= 13;

    return Container(
      padding: EdgeInsets.all(t.space.l),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(t.radius.m),
        border: Border.all(color: c.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: t.space.xs,
        children: [
          if (below) ...[
            info,
            Align(alignment: Alignment.centerRight, child: action),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: t.space.m,
              children: [
                Expanded(child: info),
                action,
              ],
            ),
          if (state case DkModelDownloading(
            :final progress,
            :final detail,
          )) ...[
            SizedBox(height: t.space.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(t.radius.pill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                color: c.primary,
                backgroundColor: c.outline,
              ),
            ),
            DkNumberText(detail, style: caption),
          ],
        ],
      ),
    );
  }
}
