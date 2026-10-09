import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_radio_row.dart';
import '../../components/dk_settings_row.dart';
import '../../components/dk_sheet.dart';
import '../../components/dk_switch.dart';
import '../../l10n/app_localizations.dart';
import 'scanner_settings.dart';

extension ScanFilterLabel on ScanFilterChoice {
  String label(AppLocalizations l) => switch (this) {
    ScanFilterChoice.original => l.filter_original,
    ScanFilterChoice.autoColour => l.filter_auto_colour,
    ScanFilterChoice.greyscale => l.filter_greyscale,
    ScanFilterChoice.blackWhite => l.filter_black_white,
    ScanFilterChoice.removeShadows => l.filter_remove_shadows,
  };
}

extension ScanPageSizeLabel on ScanPageSize {
  String label(AppLocalizations l) => switch (this) {
    ScanPageSize.auto => l.scan_page_auto,
    ScanPageSize.a4 => l.scan_page_a4,
    ScanPageSize.letter => l.scan_page_letter,
  };

  /// The sizes in the order a user expects: A4 before Letter in German.
  static List<ScanPageSize> ordered(Locale locale) =>
      locale.languageCode == 'de'
      ? const [ScanPageSize.auto, ScanPageSize.a4, ScanPageSize.letter]
      : const [ScanPageSize.auto, ScanPageSize.letter, ScanPageSize.a4];
}

/// S1's quick settings (DK-0369), from the top bar's tune button: the
/// scanning defaults that matter while capturing, the same stored values as
/// Settings → Scanning. A change applies to the next capture.
Future<void> showScannerQuickSettings(
  BuildContext context, {
  required VoidCallback onMore,
}) => showDkSheet<void>(context, body: _QuickSettings(onMore: onMore));

class _QuickSettings extends ConsumerWidget {
  const _QuickSettings({required this.onMore});

  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final prefs = ref.watch(scannerSettingsProvider);
    final settings = ref.read(scannerSettingsProvider.notifier);
    return DkSettingsGroup(
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
          onTap: () => _pick(
            context,
            l.scan_default_filter,
            ScanFilterChoice.values,
            prefs.filter,
            (f) => f.label(l),
            settings.setFilter,
          ),
        ),
        DkSettingsRow(
          title: l.scan_page_size,
          value: prefs.pageSize.label(l),
          onTap: () => _pick(
            context,
            l.scan_page_size,
            ScanPageSizeLabel.ordered(Localizations.localeOf(context)),
            prefs.pageSize,
            (s) => s.label(l),
            settings.setPageSize,
          ),
        ),
        DkSettingsRow(
          title: l.scan_more_settings,
          onTap: () {
            Navigator.of(context).pop();
            onMore();
          },
        ),
      ],
    );
  }

  /// A choice in a second small sheet: radio rows; picking one closes it.
  static Future<void> _pick<T>(
    BuildContext context,
    String title,
    List<T> options,
    T current,
    String Function(T) label,
    Future<void> Function(T) onPick,
  ) => showDkSheet<void>(
    context,
    title: title,
    body: Builder(
      builder: (sheet) => RadioGroup<T>(
        groupValue: current,
        onChanged: (v) {
          if (v == null) return;
          onPick(v);
          Navigator.of(sheet).pop();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options) DkRadioRow<T>(value: o, label: label(o)),
          ],
        ),
      ),
    ),
  );
}
