import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:flutter/material.dart';

import '../components/dk_chip.dart';
import '../components/dk_level_card.dart';
import '../components/dk_sheet.dart';
import '../components/dk_button.dart';
import '../components/dk_text_field.dart';
import '../l10n/app_localizations.dart';
import '../l10n/formats.dart';
import '../theme/dk_tokens.dart';
import 'tool_definition.dart';

/// How small: a level (Light · Recommended · Strong), or a target in bytes
/// (Under 1 MB · Under 2 MB · Under 5 MB · Custom…). Choosing one clears the
/// other (UI spec §21, Compress PDF).
typedef CompressSize = ({CompressPreset? level, int? target});

/// The output's size as a share of the input's, per level, for the
/// estimates ("≈ 1.9 MB" from 8.4 MB, as the design export shows).
/// ponytail: fixed ratios; the real size depends on the images. Measure on
/// the golden-PDF corpus (DK-0658) if the estimates mislead.
const _share = {
  CompressPreset.low: 0.61,
  CompressPreset.recommended: 0.23,
  CompressPreset.strong: 0.11,
};

const _mb = 1000 * 1000;

/// Compress PDF's T2 (DK-0463; UI spec §21): Level as three cards with
/// estimates, Target size as chips, and under More options Greyscale and
/// Remove metadata. The button: "Compress 12 pages" ("Compress 4 files" for
/// several).
final compressDefinition = ToolDefinition(
  id: 'compress',
  options: [
    ToolCustom(
      key: 'size',
      title: (l) => l.compress_level,
      initial: (level: CompressPreset.recommended, target: null),
      builder: (context, subject, value, onChanged) => _SizeControl(
        subject: subject,
        value: value! as CompressSize,
        onChanged: onChanged,
      ),
    ),
  ],
  moreOptions: [
    ToolSwitch(
      key: 'greyscale',
      title: (l) => l.compress_greyscale,
      help: (l) => l.compress_greyscale_help,
    ),
    ToolSwitch(
      key: 'metadata',
      title: (l) => l.compress_remove_metadata,
      help: (l) => l.compress_remove_metadata_help,
    ),
  ],
  action: (l, s) => s.files.length > 1
      ? l.compress_action_files(s.files.length)
      : l.compress_action_pages(s.pages),
  estimate: (l, s, v) {
    final size = v['size']! as CompressSize;
    final total = s.files.fold(0, (n, f) => n + f.size);
    final locale = l.localeName;
    return size.target != null
        ? l.compress_estimate_target(formatBytes(size.target!, locale), s.pages)
        : l.compress_estimate(
            formatBytes((total * _share[size.level]!).round(), locale),
            s.pages,
          );
  },
  input: (s, v, env) {
    final size = v['size']! as CompressSize;
    return CompressInput(
      files: [for (final f in s.files) f.path],
      outputDir: env.outputDir,
      suffix: env.l10n.compress_suffix,
      preset: size.level ?? CompressPreset.recommended,
      targetBytes: size.target,
      greyscale: v['greyscale']! as bool,
      removeMetadata: v['metadata']! as bool,
    );
  },
);

class _SizeControl extends StatelessWidget {
  const _SizeControl({
    required this.subject,
    required this.value,
    required this.onChanged,
  });

  final ToolSubject subject;
  final CompressSize value;
  final ValueChanged<Object?> onChanged;

  Future<void> _custom(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final field = TextEditingController();
    final mb = await showDkSheet<double>(
      context,
      title: l.compress_custom_title,
      body: Builder(
        builder: (sheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: sheet.tokens.space.l,
          children: [
            DkTextField(
              label: l.compress_custom_label,
              controller: field,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            DkButton(
              label: l.common_done,
              expand: true,
              onPressed: () =>
                  Navigator.of(sheet)
                      .pop(double.tryParse(field.text.replaceAll(',', '.'))),
            ),
          ],
        ),
      ),
    );
    field.dispose();
    if (mb != null && mb > 0) {
      onChanged((level: null, target: (mb * _mb).round()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final locale = l.localeName;
    final total = subject.files.fold(0, (n, f) => n + f.size);
    String estimate(CompressPreset p) =>
        '≈$unitSpace${formatBytes((total * _share[p]!).round(), locale)}';
    const targets = [1 * _mb, 2 * _mb, 5 * _mb];
    final custom = value.target != null && !targets.contains(value.target);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: t.space.s,
      children: [
        DkLevelCards<CompressPreset?>(
          levels: [
            (
              CompressPreset.low,
              (
                title: l.compress_light,
                estimate: estimate(CompressPreset.low),
                description: l.compress_light_desc,
              ),
            ),
            (
              CompressPreset.recommended,
              (
                title: l.compress_recommended,
                estimate: estimate(CompressPreset.recommended),
                description: l.compress_recommended_desc,
              ),
            ),
            (
              CompressPreset.strong,
              (
                title: l.compress_strong,
                estimate: estimate(CompressPreset.strong),
                description: l.compress_strong_desc,
              ),
            ),
          ],
          // A target clears the level.
          selected: value.level,
          onChanged: (p) => onChanged((level: p, target: null)),
        ),
        Padding(
          padding: EdgeInsets.only(top: t.space.m),
          child: Text(
            l.compress_target,
            style: t.text.titleS.copyWith(color: t.color.textPrimary),
          ),
        ),
        Wrap(
          spacing: t.space.s,
          runSpacing: t.space.s,
          children: [
            for (final b in targets)
              DkChip(
                kind: DkChipKind.choice,
                label: l.compress_under(formatBytes(b, locale)),
                selected: value.target == b,
                onSelected: (on) => onChanged(
                  on
                      ? (level: null, target: b)
                      : (level: CompressPreset.recommended, target: null),
                ),
              ),
            DkChip(
              kind: DkChipKind.choice,
              label: custom
                  ? l.compress_under(formatBytes(value.target!, locale))
                  : l.compress_custom,
              selected: custom,
              onSelected: (_) => _custom(context),
            ),
          ],
        ),
        if (value.target != null)
          Text(
            l.compress_target_hint(formatBytes(value.target!, locale)),
            style: t.text.caption.copyWith(color: t.color.textSecondary),
          ),
      ],
    );
  }
}
