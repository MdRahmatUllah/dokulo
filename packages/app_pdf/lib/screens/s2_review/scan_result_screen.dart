import 'package:flutter/material.dart';

import '../../components/dk_action_bar.dart';
import '../../components/dk_next_chip.dart';
import '../../components/dk_result_card.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/formats.dart';
import '../../theme/dk_tokens.dart';

/// What a saved scan is, for its result screen.
typedef SavedScan = ({
  String name,

  /// The (first) saved file, for Open and the Next chips.
  String path,
  int pages,
  int bytes,

  /// Pages with recognised text; null: Make text searchable was off.
  int? textPages,

  /// The folder in Files it went to ("Apartment/Bills"); null: Files.
  String? folder,
});

/// The scan's result (DK-0360; UI spec §19.4, design
/// `10-scanner/scanner-review-result`): "Scan saved", T3's result card (the
/// pages; the size, how much text was found and where it went), the file
/// name, Next chips (Compress · Add password · Sign · Summarize) and Share ·
/// Open below. A chip opens its tool with this file ([onTool]); prototype flow 1
/// goes on from Compress to Share.
class ScanResultScreen extends StatelessWidget {
  const ScanResultScreen({
    super.key,
    required this.scan,
    required this.onClose,
    required this.onOpen,
    required this.onTool,
    required this.onShare,
  });

  final SavedScan scan;
  final VoidCallback onClose, onOpen, onShare;

  /// A Next chip's tool id ('compress', 'protect', 'sign', 'summarize').
  final ValueChanged<String> onTool;

  static const nextTools = ['compress', 'protect', 'sign', 'summarize'];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final locale = l.localeName;
    return Scaffold(
      backgroundColor: c.background,
      appBar: DkTopBar(
        title: l.scan_saved,
        leading: DkTopBarLeading.close,
        onLeading: onClose,
      ),
      body: ListView(
        padding: EdgeInsets.all(t.space.l),
        children: [
          DkResultCard(
            headline: l.scan_result_pages(scan.pages),
            delta: formatBytes(scan.bytes, locale),
            sub: [
              if (scan.textPages case final n?)
                l.scan_text_found(n, scan.pages),
              [l.shell_tab_files, ...?scan.folder?.split('/')].join(' › '),
            ].join(' · '),
          ),
          SizedBox(height: t.space.xl),
          Text(
            l.scan_file_name,
            style: t.text.labelM.copyWith(color: c.textSecondary),
          ),
          SizedBox(height: t.space.xs),
          Text(scan.name, style: t.text.bodyL.copyWith(color: c.textPrimary)),
          SizedBox(height: t.space.xl),
          Semantics(
            header: true,
            child: Text(
              l.scan_next,
              style: t.text.titleS.copyWith(color: c.textPrimary),
            ),
          ),
          SizedBox(height: t.space.s),
          Wrap(
            spacing: t.space.s,
            runSpacing: t.space.s,
            children: [
              for (final id in nextTools)
                DkNextChip(toolId: id, onTap: () => onTool(id)),
            ],
          ),
        ],
      ),
      bottomNavigationBar: DkActionBar(
        label: l.common_open,
        onPressed: onOpen,
        secondaryLabel: l.common_share,
        onSecondary: onShare,
        secondaryBeside: true,
      ),
    );
  }
}
