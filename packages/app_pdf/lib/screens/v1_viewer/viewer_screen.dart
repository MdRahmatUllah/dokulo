import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_loading_spinner.dart';
import '../../components/dk_banner.dart';
import '../../components/dk_editor_bars.dart';
import '../../components/dk_pdf_canvas.dart';
import '../../components/dk_skeleton.dart';
import '../../components/dk_toast.dart';
import '../../l10n/app_localizations.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';
import '../../patterns/dk_viewer_dialogs.dart';
import '../../providers/link_providers.dart';
import '../../providers/prefs_providers.dart';
import 'viewer_providers.dart';
import 'viewer_states.dart';

/// V1, the viewer (UI spec §17.1). This is its core (DK-0293): the file's
/// pages on [DkPdfCanvas]; while the file opens, the page skeleton (DK-0620).
/// A locked PDF asks for its password, a damaged one says so (DK-0301..
/// DK-0305). The top bar, page pill and bottom bar come with DK-0294.
/// The prefs key of V1's night mode (UI spec §17.1; DK-1089).
const viewerNightKey = 'viewer.night';

class ViewerScreen extends ConsumerStatefulWidget {
  const ViewerScreen({super.key, required this.fileId, this.page});

  final int fileId;

  /// Where it opens, 1-based (a search hit, DK-0269); the first page if null.
  // ponytail: the page only; the hit's term is highlighted once V1 search
  // lands, which will take it as a second parameter.
  final int? page;

  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen> {
  /// The password that opened a locked PDF, for this visit only.
  String? _password;

  /// Locked: does [password] open it? Then the pages, and "Unlocked for
  /// viewing · Remove password" (DK-0303).
  Future<bool> _unlock(String path, String password) async {
    final opens =
        await ref.read(viewerOpenProvider(path, password: password).future) ==
        ViewerOpen.ok;
    if (!opens || !mounted) return opens;
    setState(() => _password = password);
    final l = AppLocalizations.of(context);
    showDkToast(
      context,
      l.viewer_unlocked,
      action: l.tool_unlock_name,
      onAction: () {
        if (mounted) {
          context.push(Routes.tool('unlock', files: ['${widget.fileId}']));
        }
      },
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final file = ref.watch(viewerFileProvider(widget.fileId));
    return Scaffold(
      backgroundColor: context.tokens.color.surfaceSunken,
      body: switch (file) {
        AsyncData(:final value) => _pages(value.path),
        // The file's row is gone (deleted, or a stale link).
        AsyncError() => Center(
          child: Padding(
            padding: EdgeInsets.all(context.tokens.space.xl),
            child: Text(
              AppLocalizations.of(context).viewer_file_missing,
              style: context.tokens.text.bodyM.copyWith(
                color: context.tokens.color.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => const ViewerPageSkeleton(),
      },
    );
  }

  /// The form banner over the first page (UI spec §17.1; DK-1090): "This
  /// PDF has fillable fields." with Fill form.
  Widget _withFormBanner(String path, Widget pages) {
    final hasForm =
        ref.watch(viewerHasFormProvider(path, password: _password)).value ==
        true;
    if (!hasForm) return pages;
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return Stack(
      children: [
        pages,
        Positioned(
          left: t.space.m,
          right: t.space.m,
          top: t.space.m,
          child: DkBanner(
            text: l.viewer_form_banner,
            action: l.viewer_form_fill,
            onAction: () =>
                context.push(Routes.tool('form', files: ['${widget.fileId}'])),
          ),
        ),
      ],
    );
  }

  /// The pages, or the locked card or the damaged state (DK-0301, DK-0305).
  Widget _pages(String path) {
    final open = ref.watch(viewerOpenProvider(path, password: _password));
    return switch (open.value) {
      ViewerOpen.ok => _withFormBanner(
        path,
        DkPdfCanvas(
          path: path,
          password: _password,
          // Night mode (DK-1089), switched in the overflow menu (DK-0295).
          night: ref.watch(prefsProvider).value?[viewerNightKey] == true,
          // Copy for now; Highlight, Underline, Strike come with the
          // annotations (DK-0321), Ask AI with the AI pane (M13).
          markup: const [DkMarkupAction.copy],
          initialPage: widget.page ?? 1,
          // A web link asks first; it's the only step that leaves Dokulo
          // (DK-1088).
          onLink: (url) async {
            if (await confirmOpenLink(context, url)) {
              await ref.read(linkOpenerProvider)(url);
            }
          },
        ),
      ),
      ViewerOpen.locked => ViewerLockedCard(
        onUnlock: (password) => _unlock(path, password),
      ),
      ViewerOpen.damaged => ViewerDamaged(
        onClose: () => Navigator.of(context).maybePop(),
        onRepair: () =>
            context.push(Routes.tool('repair', files: ['${widget.fileId}'])),
      ),
      null => const ViewerPageSkeleton(),
    };
  }
}

/// V1 loading (UI spec §26.2, viewer-loading): the first page as an A4
/// skeleton with a large spinner on it, the next page's top below, 8 from
/// the edges. The pages are `color.surface` on the viewer's
/// `color.surfaceSunken` (the artboard draws them in the background's own
/// colour, so only the spinner would show), pulsing as any DkSkeleton.
class ViewerPageSkeleton extends StatelessWidget {
  const ViewerPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final page = DecoratedBox(
      decoration: BoxDecoration(
        color: t.color.surface,
        borderRadius: BorderRadius.circular(t.radius.xs),
      ),
    );
    final a4 = AspectRatio(aspectRatio: 1 / 1.4142, child: page);
    // Pages as the viewer lays them out, cut off by the screen's edge
    // (any height, any orientation).
    return DkSkeleton(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(t.space.s),
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              a4,
              DkLoadingSpinner(
                size: DkSpinnerSize.large,
                color: t.color.textDisabled, // the artboard's --t3
              ),
            ],
          ),
          SizedBox(height: t.space.s),
          a4,
        ],
      ),
    );
  }
}
