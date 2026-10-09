import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../components/dk_button.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_level_card.dart';
import '../../components/dk_pro_badge.dart';
import '../../components/dk_segmented.dart';
import '../../components/dk_sheet.dart';
import '../../components/dk_switch.dart';
import '../../components/dk_text_field.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/formats.dart';
import '../../providers/file_providers.dart';
import '../../theme/dk_tokens.dart';
import '../s1_scanner/scanner_quick_settings.dart';
import '../s1_scanner/scanner_settings.dart';

enum ScanFormat { pdf, jpg }

/// The Save sheet's quality levels: how far pages are scaled down and how
/// hard their JPEGs are compressed.
enum ScanQuality {
  smaller(longSide: 1600, jpeg: 70, share: 0.25),
  recommended(longSide: 2400, jpeg: 82, share: 0.5),
  best(longSide: null, jpeg: 92, share: 1);

  const ScanQuality({
    required this.longSide,
    required this.jpeg,
    required this.share,
  });

  /// The page's long side in pixels at most (null: as photographed).
  final int? longSide;
  final int jpeg;

  /// The output's size as a share of the photos' (the estimate).
  /// ponytail: a fixed ratio; measure on real scans if estimates are off.
  final double share;
}

/// What the Save sheet chose.
typedef ScanSaveOptions = ({
  String name,
  ScanFormat format,
  ScanPageSize pageSize,
  ScanQuality quality,
  String? folder,
  bool searchable,
});

/// Whether "Make text searchable" (OCR, a Pro tool) can be switched on.
enum ScanOcrAccess {
  /// Pro: on by default.
  pro,

  /// Free, with the one free try left: off by default, the caption says so.
  freeTry,

  /// Free, the try used: off and disabled (the paywall is DK-0374's).
  locked,
}

/// Pro gating for the scanner's OCR. ponytail: every user has the free try
/// until the Free/Pro config (DK-0540) and the paywall (DK-0374) land.
final scanOcrAccessProvider = Provider<ScanOcrAccess>(
  (ref) => ScanOcrAccess.freeTry,
);

/// The user folder's subfolders, as paths relative to it ("Taxes/2025"),
/// for the Save sheet's folder row.
final scanFoldersProvider = Provider<Future<List<String>> Function()>(
  (ref) => () async {
    final root = (await ref.read(fileStoreProvider.future)).userFolder;
    if (!await root.exists()) return const [];
    final prefix = root.path.length + 1;
    final folders = <String>[];
    await for (final e in root.list(recursive: true)) {
      final path = e.path
          .substring(prefix)
          .replaceAll(Platform.pathSeparator, '/');
      // Hidden folders (".thumbnails") are the system's.
      if (e is Directory && !path.split('/').any((s) => s.startsWith('.'))) {
        folders.add(path);
      }
    }
    return folders..sort();
  },
);

/// The time a scan is named after (tests fix it).
final scanClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// A scan's name from Settings → Scanning's [pattern] (DK-0361): `{date}`
/// is 2026-10-07, `{time}` 14.32, `{number}` [number]. The default gives
/// "Scan 2026-10-07 14.32".
String scanName(
  DateTime now, {
  String pattern = defaultNamePattern,
  int number = 1,
}) => pattern
    .replaceAll('{date}', DateFormat('yyyy-MM-dd').format(now))
    .replaceAll('{time}', DateFormat('HH.mm').format(now))
    .replaceAll('{number}', '$number')
    .trim();

/// The Save sheet over S2 (DK-0359; UI spec §19.4, design
/// `10-scanner/scanner-review-save`): Name (selected, ready to type over),
/// Format PDF · JPG, Page size, Quality with size estimates, Folder (last
/// used) and "Make text searchable"; the sticky button says what happens
/// ("Save PDF · 6 pages", "Save 6 images"). Returns the choices, or null.
///
/// [photoBytes] is the size of the photos together (the estimates scale
/// from it); [folders] lists the user folder's subfolders.
Future<ScanSaveOptions?> showScanSaveSheet(
  BuildContext context, {
  required int pages,
  required int photoBytes,
  required Future<List<String>> Function() folders,
  DateTime? now,
}) {
  final l = AppLocalizations.of(context);
  return showDkSheet<ScanSaveOptions>(
    context,
    title: l.scan_save_title,
    showClose: true,
    detent: DkSheetDetent.large,
    body: _SaveSheet(
      pages: pages,
      photoBytes: photoBytes,
      folders: folders,
      name: scanName(
        now ?? DateTime.now(),
        pattern: ProviderScope.containerOf(context)
            .read(scannerSettingsProvider)
            .namePattern,
      ),
    ),
  );
}

class _SaveSheet extends ConsumerStatefulWidget {
  const _SaveSheet({
    required this.pages,
    required this.photoBytes,
    required this.folders,
    required this.name,
  });

  final int pages, photoBytes;
  final Future<List<String>> Function() folders;
  final String name;

  @override
  ConsumerState<_SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends ConsumerState<_SaveSheet> {
  late final _name = TextEditingController(
    text: widget.name,
  )..selection = TextSelection(baseOffset: 0, extentOffset: widget.name.length);
  var _format = ScanFormat.pdf;
  var _quality = ScanQuality.recommended;
  late var _pageSize = ref.read(scannerSettingsProvider).pageSize;
  late String? _folder = ref.read(scannerSettingsProvider).folder;
  late var _searchable = ref.read(scanOcrAccessProvider) == ScanOcrAccess.pro;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final l = AppLocalizations.of(context);
    final folders = await widget.folders();
    if (!mounted) return;
    await showDkPickSheet<String>(
      context,
      l.scan_folder,
      ['', ...folders],
      _folder ?? '',
      (f) => _folderLabel(l, f),
      (f) async => setState(() => _folder = f.isEmpty ? null : f),
    );
  }

  String _folderLabel(AppLocalizations l, String? folder) =>
      [l.shell_tab_files, ...?folder?.split('/')].join(' › ');

  void _save() {
    final name = _name.text.trim();
    ref.read(scannerSettingsProvider.notifier).setFolder(_folder);
    Navigator.of(context).pop<ScanSaveOptions>((
      name: name.isEmpty ? widget.name : name,
      format: _format,
      pageSize: _pageSize,
      quality: _quality,
      folder: _folder,
      searchable: _format == ScanFormat.pdf && _searchable,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final access = ref.watch(scanOcrAccessProvider);
    Widget label(String text) => Padding(
      padding: EdgeInsets.only(top: t.space.l, bottom: t.space.s),
      child: Text(text, style: t.text.titleS.copyWith(color: c.textPrimary)),
    );
    String estimate(ScanQuality q) =>
        '≈$unitSpace${formatBytes((widget.photoBytes * q.share).round(), locale.toLanguageTag())}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DkTextField(label: l.scan_name, controller: _name, autofocus: true),
        label(l.scan_format),
        DkSegmented<ScanFormat>(
          segments: const [(ScanFormat.pdf, 'PDF'), (ScanFormat.jpg, 'JPG')],
          selected: _format,
          onChanged: (f) => setState(() => _format = f),
        ),
        label(l.scan_page_size),
        DkSegmented<ScanPageSize>(
          segments: [
            for (final s in ScanPageSizeLabel.ordered(locale)) (s, s.label(l)),
          ],
          selected: _pageSize,
          onChanged: (s) => setState(() => _pageSize = s),
        ),
        label(l.scan_quality),
        DkLevelCards<ScanQuality>(
          levels: [
            for (final (q, title, description) in [
              (
                ScanQuality.smaller,
                l.scan_quality_smaller,
                l.scan_quality_smaller_desc,
              ),
              (
                ScanQuality.recommended,
                l.scan_quality_recommended,
                l.scan_quality_recommended_desc,
              ),
              (ScanQuality.best, l.scan_quality_best, l.scan_quality_best_desc),
            ])
              (
                q,
                (title: title, estimate: estimate(q), description: description),
              ),
          ],
          selected: _quality,
          onChanged: (q) => setState(() => _quality = q),
        ),
        SizedBox(height: t.space.m),
        Semantics(
          button: true,
          label: '${l.scan_folder}, ${_folderLabel(l, _folder)}',
          excludeSemantics: true,
          onTap: _pickFolder,
          child: InkWell(
            onTap: _pickFolder,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.scan_folder,
                      style: t.text.titleS.copyWith(color: c.textPrimary),
                    ),
                  ),
                  Text(
                    _folderLabel(l, _folder),
                    style: t.text.bodyM.copyWith(color: c.textSecondary),
                  ),
                  DkIcon(DkIcons.chevronRight, color: c.iconSecondary),
                ],
              ),
            ),
          ),
        ),
        if (_format == ScanFormat.pdf)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              spacing: t.space.s,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        spacing: t.space.s,
                        children: [
                          Flexible(
                            child: Text(
                              l.tool_ocr_name,
                              style: t.text.titleS.copyWith(
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                          if (access != ScanOcrAccess.pro)
                            const DkProBadge(small: true),
                        ],
                      ),
                      if (access == ScanOcrAccess.freeTry)
                        Text(
                          l.pro_free_try,
                          style: t.text.caption.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                DkSwitch(
                  value: _searchable,
                  label: l.tool_ocr_name,
                  onChanged: access == ScanOcrAccess.locked
                      ? null
                      : (v) => setState(() => _searchable = v),
                ),
              ],
            ),
          ),
        SizedBox(height: t.space.l),
        DkButton(
          label: _format == ScanFormat.pdf
              ? l.scan_save_pdf(widget.pages)
              : l.scan_save_images(widget.pages),
          expand: true,
          onPressed: _save,
        ),
      ],
    );
  }
}
