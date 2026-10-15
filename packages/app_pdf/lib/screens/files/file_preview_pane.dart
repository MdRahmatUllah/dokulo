import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_button.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_icon_button.dart';
import '../../components/dk_next_chip.dart';
import '../../components/dk_page_thumb.dart';
import '../../l10n/app_localizations.dart';
import '../../patterns/dk_file_actions.dart';
import '../../patterns/dk_file_info.dart';
import '../../providers/database_providers.dart';
import '../../providers/files_providers.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';
import '../t2_tool/tool_options_providers.dart';
import 'files_screen.dart' show fileMeta;

/// F1's preview pane on a large tablet (DK-0279; UI spec §30): the
/// selected file's first page large, its name and meta, Open · Share ·
/// More, the quick tools (Compress, Sign, Add password, Black out), the
/// page strip and the Info table. Nothing selected (an empty folder): the
/// pane stays empty.
class FilePreviewPane extends ConsumerWidget {
  const FilePreviewPane({super.key, required this.file});

  final FileEntry? file;

  /// The quick tools under the actions (the tablet-files frame).
  static const tools = ['compress', 'sign', 'protect', 'redact'];

  /// Pages in the strip; the viewer has the rest.
  static const stripPages = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = this.file;
    final t = context.tokens;
    if (file == null) return ColoredBox(color: t.color.background);
    final c = t.color;
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final first = ref.watch(fileThumbnailProvider(file.path, 360));
    void open({int? page}) {
      recordOpened(ref.read(appDatabaseProvider), file.id);
      context.push(Routes.viewer('${file.id}', page: page));
    }

    Widget header(String text) => Padding(
      padding: EdgeInsets.only(top: t.space.xl, bottom: t.space.m),
      child: Semantics(
        header: true,
        child: Text(text, style: t.text.titleS.copyWith(color: c.textPrimary)),
      ),
    );

    return ColoredBox(
      color: c.background,
      child: ListView(
        padding: EdgeInsets.all(t.space.xl),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: t.space.l,
            children: [
              Container(
                width: 180,
                height: 240,
                decoration: BoxDecoration(
                  color: c.pageWhite,
                  border: Border.all(color: c.outline),
                  borderRadius: BorderRadius.circular(t.radius.xs),
                ),
                clipBehavior: Clip.antiAlias,
                child: switch (first) {
                  AsyncData(:final value) => RawImage(
                    image: value,
                    fit: BoxFit.cover,
                  ),
                  _ => const SizedBox.shrink(),
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: t.space.s,
                  children: [
                    Text(
                      file.name,
                      style: t.text.titleM.copyWith(color: c.textPrimary),
                    ),
                    Text(
                      fileMeta(file, l, locale),
                      style: t.text.bodyM.copyWith(color: c.textSecondary),
                    ),
                    SizedBox(height: t.space.s),
                    Wrap(
                      spacing: t.space.s,
                      runSpacing: t.space.s,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DkButton(
                          label: l.common_open,
                          icon: DkIcons.open,
                          onPressed: open,
                        ),
                        // ponytail: off until share_plus lands (DK-1077),
                        // as the file action sheet's Share.
                        DkButton(
                          label: l.common_share,
                          icon: DkIcons.share(context),
                          variant: DkButtonVariant.tertiary,
                          onPressed: null,
                        ),
                        DkIconButton(
                          icon: DkIcons.overflow(context),
                          tooltip: l.files_more_actions,
                          onPressed: () => showFileActions(context, ref, file),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: t.space.s,
                      runSpacing: t.space.s,
                      children: [
                        for (final id in tools)
                          DkNextChip(
                            toolId: id,
                            onTap: () => context.push(
                              Routes.tool(id, files: ['${file.id}']),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (file.pages > 0) ...[
            header(l.info_pages),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: file.pages.clamp(0, stripPages),
                separatorBuilder: (_, _) => SizedBox(width: t.space.s),
                itemBuilder: (_, i) => SizedBox(
                  width: 64,
                  child: _StripPage(file: file, page: i + 1, onTap: open),
                ),
              ),
            ),
          ],
          header(l.common_info),
          // 560 at most, as the frame (a list stretches its children).
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: t.space.l),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.outline),
                  borderRadius: BorderRadius.circular(t.radius.m),
                ),
                child: FileInfoRows(file),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StripPage extends ConsumerWidget {
  const _StripPage({
    required this.file,
    required this.page,
    required this.onTap,
  });

  final FileEntry file;
  final int page;
  final void Function({int? page}) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(pdfThumbnailProvider(file.path, page: page));
    return DkPageThumb(
      pageNumber: page,
      pageCount: file.pages,
      page: switch (image) {
        AsyncData(:final value) => RawImage(image: value, fit: BoxFit.cover),
        _ => null,
      },
      onTap: () => onTap(page: page),
    );
  }
}
