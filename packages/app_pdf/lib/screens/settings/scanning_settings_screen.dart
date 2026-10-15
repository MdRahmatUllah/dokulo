import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_button.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_radio_row.dart';
import '../../components/dk_settings_row.dart';
import '../../components/dk_switch.dart';
import '../../components/dk_text_field.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dk_tokens.dart';
import '../s1_scanner/scanner_quick_settings.dart';
import '../s1_scanner/scanner_settings.dart';
import '../s2_review/save_sheet.dart';

extension ScanOcrLanguageLabel on ScanOcrLanguage {
  String label(AppLocalizations l) => switch (this) {
    ScanOcrLanguage.auto => l.scan_page_auto,
    ScanOcrLanguage.english => l.settings_language_english,
    ScanOcrLanguage.german => l.settings_language_deutsch,
  };
}

/// Settings → Scanning (DK-0361; design `22-me-settings/me-scanning`): the
/// scanner's defaults, the same values S1's quick settings and S2's "Use as
/// default" write. They apply to the next scan and to imported photos.
/// ponytail: "Find documents in photos" joins with the photo finder's
/// screens (DK-0363).
class ScanningSettingsScreen extends ConsumerStatefulWidget {
  const ScanningSettingsScreen({super.key});

  @override
  ConsumerState<ScanningSettingsScreen> createState() =>
      _ScanningSettingsScreenState();
}

class _ScanningSettingsScreenState
    extends ConsumerState<ScanningSettingsScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(scannerSettingsProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.tokens.color;
    final prefs = ref.watch(scannerSettingsProvider);
    final settings = ref.read(scannerSettingsProvider.notifier);
    final locale = Localizations.localeOf(context);
    void push(Widget page) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));
    return Scaffold(
      backgroundColor: c.background,
      appBar: DkTopBar(title: l.settings_scanning),
      body: ListView(
        children: [
          DkSettingsGroup(
            children: [
              DkSettingsRow(
                title: l.camera_auto_capture,
                description: l.scan_auto_capture_desc,
                trailing: DkSwitch(
                  value: prefs.autoCapture,
                  onChanged: settings.setAutoCapture,
                ),
                onTap: () => settings.setAutoCapture(!prefs.autoCapture),
              ),
              DkSettingsRow(
                title: l.scan_auto_crop,
                description: l.scan_auto_crop_desc,
                trailing: DkSwitch(
                  value: prefs.autoCrop,
                  onChanged: settings.setAutoCrop,
                ),
                onTap: () => settings.setAutoCrop(!prefs.autoCrop),
              ),
              DkSettingsRow(
                title: l.scan_default_filter,
                value: prefs.filter.label(l),
                onTap: () => push(const DefaultFilterScreen()),
              ),
              DkSettingsRow(
                title: l.scan_page_size,
                value: prefs.pageSize.label(l),
                onTap: () => showDkPickSheet(
                  context,
                  l.scan_page_size,
                  ScanPageSizeLabel.ordered(locale),
                  prefs.pageSize,
                  (s) => s.label(l),
                  settings.setPageSize,
                ),
              ),
              DkSettingsRow(
                title: l.settings_file_name,
                value: prefs.namePattern,
                onTap: () => push(const FileNamePatternScreen()),
              ),
              DkSettingsRow(
                title: l.settings_ocr_language,
                value: prefs.ocrLanguage.label(l),
                onTap: () => showDkPickSheet(
                  context,
                  l.settings_ocr_language,
                  ScanOcrLanguage.values,
                  prefs.ocrLanguage,
                  (o) => o.label(l),
                  settings.setOcrLanguage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Settings → Scanning → Default filter (design `me-filter`): the five
/// filters with what each is for.
class DefaultFilterScreen extends ConsumerWidget {
  const DefaultFilterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final prefs = ref.watch(scannerSettingsProvider);
    String description(ScanFilterChoice f) => switch (f) {
      ScanFilterChoice.original => l.filter_original_desc,
      ScanFilterChoice.autoColour => l.filter_auto_colour_desc,
      ScanFilterChoice.greyscale => l.filter_greyscale_desc,
      ScanFilterChoice.blackWhite => l.filter_black_white_desc,
      ScanFilterChoice.removeShadows => l.filter_remove_shadows_desc,
    };
    return Scaffold(
      backgroundColor: t.color.background,
      appBar: DkTopBar(title: l.scan_default_filter),
      body: ListView(
        padding: EdgeInsets.all(t.space.l),
        children: [
          RadioGroup<ScanFilterChoice>(
            groupValue: prefs.filter,
            onChanged: (f) {
              if (f != null) {
                ref.read(scannerSettingsProvider.notifier).setFilter(f);
              }
            },
            child: Column(
              children: [
                for (final f in ScanFilterChoice.values)
                  DkRadioRow<ScanFilterChoice>(
                    value: f,
                    label: f.label(l),
                    description: description(f),
                  ),
              ],
            ),
          ),
          SizedBox(height: t.space.l),
          Text(
            l.filter_default_footer,
            style: t.text.caption.copyWith(color: t.color.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Settings → Scanning → File name (design `me-filename`): the pattern,
/// chips that insert `{date}`, `{time}` and `{number}`, and a preview.
class FileNamePatternScreen extends ConsumerStatefulWidget {
  const FileNamePatternScreen({super.key});

  @override
  ConsumerState<FileNamePatternScreen> createState() =>
      _FileNamePatternScreenState();
}

class _FileNamePatternScreenState extends ConsumerState<FileNamePatternScreen> {
  late final _pattern = TextEditingController(
    text: ref.read(scannerSettingsProvider).namePattern,
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _pattern.dispose();
    super.dispose();
  }

  void _insert(String token) {
    final v = _pattern.value;
    final at = v.selection.isValid ? v.selection.end : v.text.length;
    final text = v.text.replaceRange(
      v.selection.isValid ? v.selection.start : at,
      at,
      token,
    );
    final caret = (v.selection.isValid ? v.selection.start : at) + token.length;
    _pattern.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final now = ref.read(scanClockProvider)();
    return Scaffold(
      backgroundColor: c.background,
      appBar: DkTopBar(title: l.settings_file_name),
      body: ListView(
        padding: EdgeInsets.all(t.space.l),
        children: [
          DkTextField(label: l.settings_name_pattern, controller: _pattern),
          SizedBox(height: t.space.l),
          Text(l.settings_insert, style: t.text.titleS),
          SizedBox(height: t.space.s),
          Wrap(
            spacing: t.space.s,
            runSpacing: t.space.s,
            children: [
              for (final (token, label) in [
                ('{date}', l.settings_token_date),
                ('{time}', l.settings_token_time),
                ('{number}', l.settings_token_number),
              ])
                DkButton(
                  label: label,
                  icon: DkIcons.add,
                  size: DkButtonSize.compact,
                  variant: DkButtonVariant.secondary,
                  onPressed: () => _insert(token),
                ),
            ],
          ),
          SizedBox(height: t.space.xl),
          Text(l.settings_preview, style: t.text.titleS),
          SizedBox(height: t.space.s),
          Text(
            '${scanName(now, pattern: _pattern.text)}.pdf',
            style: t.text.bodyL.copyWith(color: c.textSecondary),
          ),
          SizedBox(height: t.space.xl),
          DkButton(
            label: l.common_save,
            expand: true,
            onPressed: () async {
              await ref
                  .read(scannerSettingsProvider.notifier)
                  .setNamePattern(_pattern.text);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
