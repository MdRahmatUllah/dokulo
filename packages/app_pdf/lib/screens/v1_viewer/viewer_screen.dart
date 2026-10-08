import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_loading_spinner.dart';
import '../../components/dk_pdf_canvas.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dk_tokens.dart';
import 'viewer_providers.dart';

/// V1, the viewer (UI spec §17.1). This is its core (DK-0293): the file's
/// pages on [DkPdfCanvas]. The top bar, page pill, bottom bar and the states
/// (loading skeleton, locked, damaged, search, night) come with their own
/// tasks.
class ViewerScreen extends ConsumerWidget {
  const ViewerScreen({super.key, required this.fileId});

  final int fileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(viewerFileProvider(fileId));
    return Scaffold(
      backgroundColor: context.tokens.color.surfaceSunken,
      body: switch (file) {
        AsyncData(:final value) => DkPdfCanvas(path: value.path),
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
        // ponytail: the loading skeleton and the damaged/locked states are
        // V1's own state tasks; until then a spinner.
        _ => const Center(child: DkLoadingSpinner()),
      },
    );
  }
}
