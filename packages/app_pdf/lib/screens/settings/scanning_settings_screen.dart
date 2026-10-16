import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_button.dart';
import '../../components/dk_chip.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_settings_row.dart';
import '../../components/dk_switch.dart';
import '../../components/dk_text_field.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../photo_finder/photo_finder.dart' show photoFinderKey;
import '../../photo_finder/photo_finder_screens.dart' show startPhotoFinder;
import '../../providers/prefs_providers.dart';
import '../../theme/dk_tokens.dart';
import '../s1_scanner/scanner_quick_settings.dart';
import '../s1_scanner/scanner_settings.dart';
import '../s2_review/s2_screen.dart' show scanPreviewFilter;
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
    final t = context.tokens;
    final c = t.color;
    final prefs = ref.watch(scannerSettingsProvider);
    final settings = ref.read(scannerSettingsProvider.notifier);
    final locale = Localizations.localeOf(context);
    final findPhotos = ref.watch(prefsProvider).value?[photoFinderKey] == true;
    void setFindPhotos(bool on) => on
        ? startPhotoFinder(context, ref)
        : ref.read(prefsProvider.notifier).set(photoFinderKey, false);
    void push(Widget page) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));
    return Scaffold(
      backgroundColor: c.background,
      appBar: DkTopBar(title: l.settings_scanning),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          t.space.l,
          t.space.s,
          t.space.l,
          t.space.l,
        ),
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
              // DK-0571: on asks through the photo finder's intro (the only
              // place photo access is asked) and scans; off stops it.
              DkSettingsRow(
                title: l.settings_find_photos,
                description: l.settings_find_photos_help,
                trailing: DkSwitch(value: findPhotos, onChanged: setFindPhotos),
                onTap: () => setFindPhotos(!findPhotos),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Settings → Scanning → Default filter (design `me-filter`): the five
/// filters in an inset card, each with a page under its filter and what it
/// is for; the chosen one has the check.
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
        padding: EdgeInsets.fromLTRB(
          t.space.l,
          t.space.s,
          t.space.l,
          t.space.l,
        ),
        children: [
          DkSettingsGroup(
            children: [
              for (final f in ScanFilterChoice.values)
                // Read out as a radio: "Greyscale, not selected, 3 of 5".
                MergeSemantics(
                  child: Semantics(
                    checked: f == prefs.filter,
                    inMutuallyExclusiveGroup: true,
                    child: DkSettingsRow(
                      leading: _FilterThumb(f),
                      title: f.label(l),
                      description: description(f),
                      trailing: f == prefs.filter
                          ? DkIcon(DkIcons.check, color: t.color.primary)
                          : const SizedBox.square(dimension: 24),
                      onTap: () => ref
                          .read(scannerSettingsProvider.notifier)
                          .setFilter(f),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: t.space.s),
            child: Text(
              l.filter_default_footer,
              style: t.text.caption.copyWith(color: t.color.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// A 40 × 52 page (a heading and lines on photographed paper) under the
/// filter's look in S2 ([scanPreviewFilter]).
class _FilterThumb extends StatelessWidget {
  const _FilterThumb(this.filter);

  final ScanFilterChoice filter;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    // A photographed page looks the same in both themes: the light ink.
    // The design's #F2F0EA: white paper with the room's warm cast, which
    // the grey filters take out.
    final ink = DkTokens.light.color;
    final paper = Color.lerp(ink.pageWhite, ink.warning, 0.06)!;
    Widget bar(double width, Color colour) => Container(
      width: width,
      height: 2,
      margin: const EdgeInsets.only(bottom: 3),
      color: colour,
    );
    // The border stays outside the filter: Black & white would whiten it.
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 52,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          border: Border.all(color: c.outline),
          borderRadius: BorderRadius.circular(t.radius.xs),
        ),
        child: ColorFiltered(
          colorFilter: scanPreviewFilter(filter),
          child: Container(
            color: paper,
            padding: const EdgeInsets.fromLTRB(6, 5, 6, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(18, ink.iconSecondary),
                const SizedBox(height: 3),
                for (var i = 0; i < 6; i++) bar(28, ink.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The pattern's tokens. In the field each is one private-use character,
/// shown as a chip, so the caret and Delete treat a token as one piece.
const _tokens = ['{date}', '{time}', '{number}'];
String _tokenChar(int i) => String.fromCharCode(0xE000 + i);

String _toField(String pattern) {
  for (var i = 0; i < _tokens.length; i++) {
    pattern = pattern.replaceAll(_tokens[i], _tokenChar(i));
  }
  return pattern;
}

String _toPattern(String field) {
  for (var i = 0; i < _tokens.length; i++) {
    field = field.replaceAll(_tokenChar(i), _tokens[i]);
  }
  return field;
}

/// The name pattern's field: the tokens as chips (UI spec §23 "editor with
/// token chips").
class _PatternController extends TextEditingController {
  _PatternController(String pattern) : super(text: _toField(pattern));

  String get pattern => _toPattern(text);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final chips = [for (var i = 0; i < _tokens.length; i++) _tokenChar(i)];
    if (!chips.any(text.contains)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    // ponytail: no composing underline once a chip is in the field; the
    // IME still composes, it just isn't drawn.
    final l = AppLocalizations.of(context);
    final labels = [
      l.settings_token_date,
      l.settings_token_time,
      l.settings_token_number,
    ];
    final spans = <InlineSpan>[];
    var run = StringBuffer();
    for (final ch in text.split('')) {
      final i = chips.indexOf(ch);
      if (i < 0) {
        run.write(ch);
        continue;
      }
      if (run.isNotEmpty) spans.add(TextSpan(text: '$run'));
      run = StringBuffer();
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _TokenChip(labels[i]),
        ),
      );
    }
    if (run.isNotEmpty) spans.add(TextSpan(text: '$run'));
    return TextSpan(style: style, children: spans);
  }
}

class _TokenChip extends StatelessWidget {
  const _TokenChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    return Container(
      height: 22,
      padding: EdgeInsets.symmetric(horizontal: t.space.s),
      decoration: BoxDecoration(
        color: c.primaryContainer,
        borderRadius: BorderRadius.circular(t.radius.pill),
      ),
      child: Align(
        widthFactor: 1,
        child: Text(
          label,
          style: t.text.caption.copyWith(
            color: c.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Settings → Scanning → File name (design `me-filename`): the pattern with
/// its tokens as chips, chips that insert date, time and number, and a
/// preview card.
class FileNamePatternScreen extends ConsumerStatefulWidget {
  const FileNamePatternScreen({super.key});

  @override
  ConsumerState<FileNamePatternScreen> createState() =>
      _FileNamePatternScreenState();
}

class _FileNamePatternScreenState extends ConsumerState<FileNamePatternScreen> {
  late final _pattern = _PatternController(
    ref.read(scannerSettingsProvider).namePattern,
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _pattern.dispose();
    super.dispose();
  }

  void _insert(int token) {
    final v = _pattern.value;
    final at = v.selection.isValid ? v.selection.end : v.text.length;
    final from = v.selection.isValid ? v.selection.start : at;
    _pattern.value = TextEditingValue(
      text: v.text.replaceRange(from, at, _tokenChar(token)),
      selection: TextSelection.collapsed(offset: from + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final now = ref.read(scanClockProvider)();
    final preview = '${scanName(now, pattern: _pattern.pattern)}.pdf';
    return Scaffold(
      backgroundColor: c.background,
      appBar: DkTopBar(title: l.settings_file_name),
      body: ListView(
        padding: EdgeInsets.all(t.space.l),
        children: [
          DkTextField(
            label: l.settings_name_pattern,
            controller: _pattern,
            clearable: false,
          ),
          SizedBox(height: t.space.l),
          Text(
            l.settings_insert,
            style: t.text.labelM.copyWith(color: c.textSecondary),
          ),
          SizedBox(height: t.space.s),
          Wrap(
            spacing: t.space.s,
            children: [
              for (final (i, label) in [
                l.settings_token_date,
                l.settings_token_time,
                l.settings_token_number,
              ].indexed)
                DkChip(
                  label: label,
                  icon: DkIcons.add,
                  selected: false,
                  onSelected: (_) => _insert(i),
                ),
            ],
          ),
          SizedBox(height: t.space.l),
          // The field's chips aren't text to a screen reader: the preview
          // card says the name the pattern makes.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.outline),
              borderRadius: BorderRadius.circular(t.radius.m),
            ),
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.settings_preview,
                    style: t.text.caption.copyWith(color: c.textSecondary),
                  ),
                  Text(
                    preview,
                    style: t.text.bodyL.copyWith(
                      color: c.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: t.space.xl),
          DkButton(
            label: l.common_save,
            size: DkButtonSize.large,
            expand: true,
            onPressed: () async {
              await ref
                  .read(scannerSettingsProvider.notifier)
                  .setNamePattern(_pattern.pattern);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
