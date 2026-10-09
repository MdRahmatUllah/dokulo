import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../components/dk_action_bar.dart';
import '../components/dk_action_sheet.dart';
import '../components/dk_button.dart';
import '../components/dk_empty_state.dart';
import '../components/dk_icon.dart';
import '../components/dk_illustration.dart';
import '../components/dk_menu.dart';
import '../components/dk_segmented.dart';
import '../components/dk_settings_row.dart';
import '../components/dk_sheet.dart';
import '../components/dk_switch.dart';
import '../components/dk_text_action.dart';
import '../components/dk_top_bar.dart';
import '../l10n/app_localizations.dart';
import '../patterns/dk_empty_states.dart';
import '../theme/dk_tokens.dart';
import 'photo_finder.dart';

/// A library thumbnail, kept while the results are open.
final photoThumbProvider = FutureProvider.family<Uint8List?, String>(
  (ref, id) => ref.read(photoLibraryProvider).thumbnail(id),
);

/// "Find documents in your photos" (DK-0363; UI spec §19.5, design
/// `11-photo-finder/photo-finder-intro`): ILL-17, what happens, "Allow
/// photo access" (the only place full photo access is asked) and "Not now".
/// True when the user allowed it; the caller then starts the scan.
Future<bool> showPhotoFinderIntro(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final allowed = await showDkSheet<bool>(
    context,
    detent: DkSheetDetent.medium,
    body: Builder(
      builder: (sheet) => DkEmptyState(
        illustration: DkIllustrations.findInPhotos,
        title: l.photos_intro_title,
        body: l.photos_intro_body,
        action: l.photos_allow,
        onAction: () => Navigator.of(sheet).pop(true),
        secondaryAction: l.common_not_now,
        onSecondaryAction: () => Navigator.of(sheet).pop(false),
      ),
    ),
  );
  return allowed ?? false;
}

/// Home's card while the finder looks through the library (DK-0364; design
/// `photo-finder-scanning`): "Looking through photos", "1,240 of 5,800 ·
/// you can leave this screen" and a thin bar. Nothing when no scan runs.
/// ponytail: the "Found 37 documents" notification needs a notifications
/// plugin; it comes with the job notifications (follow-up).
class PhotoFinderCard extends ConsumerWidget {
  const PhotoFinderCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(photoFinderProvider);
    if (!s.running) return const SizedBox.shrink();
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final n = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(t.radius.m),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(t.space.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: t.space.xs,
            children: [
              Row(
                spacing: t.space.m,
                children: [
                  DkIcon(
                    DkIcons.importPhotos,
                    size: DkIconSize.xl,
                    color: c.primary,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.photos_scanning,
                          style: t.text.titleS.copyWith(color: c.textPrimary),
                        ),
                        Text(
                          l.photos_scanning_progress(
                            n.format(s.scanned),
                            n.format(s.total),
                          ),
                          style: t.text.caption.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: s.progress,
                  minHeight: 4,
                  color: c.primary,
                  backgroundColor: c.surfaceSunken,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What "Convert to PDF" chose (DK-0366).
typedef PhotoConvertOptions = ({bool onePdf, bool cleanUp});

/// "Documents in photos" (DK-0365, DK-0367, DK-0368; UI spec §19.5): the
/// found photos in three columns under month headers, each with a small
/// document badge. Select starts multi-select; "Convert 8 to PDF" opens the
/// options. A long press offers "Not a document" (removed and remembered)
/// and Preview. Nothing found: "No documents found in your photos." and
/// Close. [onConvert] gets the photos and the options (Image to PDF does
/// the work).
class PhotoFinderScreen extends ConsumerStatefulWidget {
  const PhotoFinderScreen({super.key, required this.onConvert});

  final void Function(List<String> ids, PhotoConvertOptions options) onConvert;

  @override
  ConsumerState<PhotoFinderScreen> createState() => _PhotoFinderScreenState();
}

class _PhotoFinderScreenState extends ConsumerState<PhotoFinderScreen> {
  /// Null: not selecting.
  Set<String>? _selected;

  @override
  void initState() {
    super.initState();
    ref.read(photoFinderProvider.notifier).load();
  }

  Future<void> _convert() async {
    final ids = [
      for (final p in ref.read(photoFinderProvider).found)
        if (_selected!.contains(p.id)) p.id,
    ];
    final options = await showPhotoConvertSheet(context, ids.length);
    if (options == null || !mounted) return;
    setState(() => _selected = null);
    widget.onConvert(ids, options);
  }

  void _preview(String id) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: context.tokens.color.cameraChrome,
        appBar: const DkTopBar(leading: DkTopBarLeading.close),
        body: Center(child: _Thumb(id, fit: BoxFit.contain)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final s = ref.watch(photoFinderProvider);
    final selected = _selected;
    final locale = Localizations.localeOf(context).toLanguageTag();

    // Month headers, newest first.
    final months = <String, List<LibraryPhoto>>{};
    for (final p in s.found) {
      months
          .putIfAbsent(DateFormat.yMMMM(locale).format(p.modified), () => [])
          .add(p);
    }

    Widget tile(LibraryPhoto p) => Builder(
      builder: (anchor) {
        final on = selected?.contains(p.id) ?? false;
        void toggle() =>
            setState(() => on ? selected!.remove(p.id) : selected!.add(p.id));
        return Semantics(
          button: true,
          selected: selected == null ? null : on,
          label: l.photos_document_photo,
          onTap: selected == null ? () => _preview(p.id) : toggle,
          onLongPress: () => _menu(anchor, p.id),
          excludeSemantics: true,
          child: GestureDetector(
            onTap: selected == null ? () => _preview(p.id) : toggle,
            onLongPress: () => _menu(anchor, p.id),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: c.surfaceSunken, child: _Thumb(p.id)),
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DkIcon(
                      DkIcons.scanDocument,
                      size: DkIconSize.s,
                      color: c.iconPrimary,
                    ),
                  ),
                ),
                if (selected != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: c.onCamera, width: 2),
                        color: on
                            ? c.primary
                            : c.cameraChrome.withValues(alpha: 0.2),
                      ),
                      child: on
                          ? DkIcon(
                              DkIcons.check,
                              size: DkIconSize.s,
                              color: c.onPrimary,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    final empty = s.found.isEmpty && !s.running;
    return Scaffold(
      backgroundColor: c.background,
      appBar: DkTopBar(
        title: l.photos_title,
        trailing: empty
            ? const SizedBox.shrink()
            : DkTextAction(
                label: selected == null ? l.common_select : l.common_cancel,
                onTap: () =>
                    setState(() => _selected = selected == null ? {} : null),
              ),
      ),
      body: empty
          ? DkEmptyStates.photoFinder(
              context,
              onClose: () => Navigator.of(context).maybePop(),
            )
          : CustomScrollView(
              slivers: [
                for (final MapEntry(key: month, value: photos)
                    in months.entries) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        t.space.l,
                        t.space.l,
                        t.space.l,
                        t.space.s,
                      ),
                      child: Semantics(
                        header: true,
                        child: Text(
                          month,
                          style: t.text.labelM.copyWith(color: c.textSecondary),
                        ),
                      ),
                    ),
                  ),
                  SliverGrid.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                    children: [for (final p in photos) tile(p)],
                  ),
                ],
                SliverToBoxAdapter(child: SizedBox(height: t.space.xl)),
              ],
            ),
      bottomNavigationBar: selected == null || selected.isEmpty
          ? null
          : DkActionBar(
              label: l.photos_convert(selected.length),
              onPressed: _convert,
            ),
    );
  }

  /// The long press (DK-0367): Not a document · Preview.
  void _menu(BuildContext anchor, String id) {
    final l = AppLocalizations.of(context);
    showDkMenu(
      anchor,
      groups: [
        [
          DkAction(
            icon: DkIcons.hideImage,
            label: l.photos_not_document,
            onTap: () {
              _selected?.remove(id);
              ref.read(photoFinderProvider.notifier).notADocument(id);
            },
          ),
          DkAction(
            icon: DkIcons.openInFull,
            label: l.photos_preview,
            onTap: () => _preview(id),
          ),
        ],
      ],
    );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb(this.id, {this.fit = BoxFit.cover});

  final String id;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(photoThumbProvider(id)).value;
    return bytes == null
        ? const SizedBox.shrink()
        : Image.memory(bytes, fit: fit, gaplessPlayback: true);
  }
}

/// "Convert 8 photos" (DK-0366; design `photo-finder-convert`): One PDF ·
/// One PDF per photo, and "Clean up like a scan" (on: the scanner's crop
/// and filter run on each photo).
Future<PhotoConvertOptions?> showPhotoConvertSheet(
  BuildContext context,
  int count,
) {
  final l = AppLocalizations.of(context);
  var onePdf = true, cleanUp = true;
  return showDkSheet<PhotoConvertOptions>(
    context,
    title: l.photos_convert_title(count),
    showClose: true,
    body: StatefulBuilder(
      builder: (sheet, setState) {
        final t = sheet.tokens;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: t.space.l,
          children: [
            DkSegmented<bool>(
              segments: [
                (true, l.photos_one_pdf),
                (false, l.photos_pdf_per_photo),
              ],
              selected: onePdf,
              onChanged: (v) => setState(() => onePdf = v),
            ),
            DkSettingsRow(
              title: l.photos_clean_up,
              description: l.photos_clean_up_desc,
              trailing: DkSwitch(
                value: cleanUp,
                onChanged: (v) => setState(() => cleanUp = v),
              ),
              onTap: () => setState(() => cleanUp = !cleanUp),
            ),
            DkButton(
              label: onePdf
                  ? l.photos_create_pdf(count)
                  : l.photos_create_pdfs(count),
              expand: true,
              onPressed: () => Navigator.of(sheet)
                  .pop<PhotoConvertOptions>((onePdf: onePdf, cleanUp: cleanUp)),
            ),
          ],
        );
      },
    ),
  );
}
