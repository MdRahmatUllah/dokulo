import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../components/dk_sheet.dart';
import '../components/dk_text_action.dart';
import '../l10n/app_localizations.dart';
import '../l10n/formats.dart';
import '../providers/files_providers.dart';
import '../routes/routes.dart';
import '../theme/dk_tokens.dart';

/// Info (DK-0275; UI spec §16.4), medium: the thumbnail and the name; then
/// Location, Size, Pages, Created, Modified, PDF version, Password and
/// Searchable text (with "Make searchable"); then Versions, the current one
/// first, each older one with Restore.
Future<void> showFileInfo(BuildContext context, FileEntry file) {
  final l = AppLocalizations.of(context);
  return showDkSheet<void>(
    context,
    title: l.common_info,
    showClose: true,
    detent: DkSheetDetent.medium,
    body: _FileInfo(file),
  );
}

class _FileInfo extends ConsumerWidget {
  const _FileInfo(this.file);

  final FileEntry file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final chain = file.folderId == null
        ? const <Folder>[]
        : ref.watch(folderChainProvider(file.folderId!)).value ?? const [];
    final version = ref.watch(pdfVersionProvider(file.path)).value;
    final versions = ref.watch(fileVersionsProvider(file.id)).value ?? const [];
    final thumb = ref.watch(fileThumbnailProvider(file.path, 96));
    String stamp(DateTime d) =>
        '${formatDate(d, locale)}, '
        '${DateFormat.Hm(locale).format(d)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          spacing: t.space.m,
          children: [
            SizedBox(
              width: 40,
              height: 52,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(t.radius.xs),
                child: switch (thumb) {
                  AsyncData(:final value) => RawImage(
                    image: value,
                    fit: BoxFit.cover,
                  ),
                  _ => ColoredBox(color: t.color.pageWhite),
                },
              ),
            ),
            Expanded(
              child: Text(
                file.name,
                style: t.text.titleS.copyWith(color: t.color.textPrimary),
              ),
            ),
          ],
        ),
        SizedBox(height: t.space.m),
        _Row(
          l.info_location,
          [l.shell_tab_files, for (final f in chain) f.name].join(' › '),
        ),
        _Row(l.info_size, formatBytes(file.size, locale)),
        if (file.pages > 0) _Row(l.info_pages, '${file.pages}'),
        _Row(l.info_created, stamp(file.created)),
        _Row(l.info_modified, formatWhen(file.modified, l, locale)),
        if (version != null) _Row(l.info_pdf_version, version),
        _Row(l.info_password, file.encrypted ? l.common_yes : l.common_no),
        _Row(
          l.info_searchable,
          file.hasText ? l.common_yes : l.common_no,
          action: file.hasText
              ? null
              : DkTextAction(
                  label: l.banner_make_searchable,
                  onTap: () {
                    Navigator.pop(context);
                    context.push(Routes.tool('ocr', files: ['${file.id}']));
                  },
                ),
        ),
        SizedBox(height: t.space.l),
        Semantics(
          header: true,
          child: Text(
            l.info_versions,
            style: t.text.titleS.copyWith(color: t.color.textPrimary),
          ),
        ),
        _Row('${formatWhen(file.modified, l, locale)} · ${l.info_current}', ''),
        for (final v in versions)
          _Row(
            formatWhen(v.createdAt, l, locale),
            '',
            action: DkTextAction(
              label: l.common_restore,
              onTap: () async {
                final store = await ref.read(versionStoreProvider.future);
                await store.restore(v);
                ref.invalidate(fileVersionsProvider(file.id));
              },
            ),
          ),
      ],
    );
  }
}

/// A label on the left, its value on the right, and an optional action
/// under the value.
class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.action});

  final String label, value;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MergeSemantics(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: t.space.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: t.space.m,
          children: [
            Expanded(
              child: Text(
                label,
                style: t.text.bodyM.copyWith(color: t.color.textSecondary),
              ),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (value.isNotEmpty)
                    Text(
                      value,
                      textAlign: TextAlign.end,
                      style: t.text.bodyM.copyWith(color: t.color.textPrimary),
                    ),
                  ?action,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
