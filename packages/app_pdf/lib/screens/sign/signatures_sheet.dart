import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_toast.dart';
import '../../components/dk_box_frame.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_settings_row.dart';
import '../../components/dk_sheet.dart';
import '../../components/dk_signature_card.dart';
import '../../components/dk_signature_pad.dart';
import '../../components/dk_switch.dart';
import '../../components/dk_tappable.dart';
import '../../l10n/app_localizations.dart';
import '../../patterns/dk_confirmations.dart';
import '../../patterns/dk_empty_states.dart';
import '../../providers/prefs_providers.dart';
import '../../providers/signature_providers.dart';
import '../../theme/dk_tokens.dart';

/// The signature pad, full screen and in landscape (DK-0327; UI spec
/// §17.3). The phone's orientations come back when it closes. Returns the
/// PNG and its ink, or null.
Future<(Uint8List, Color)?> openSignaturePad(BuildContext context) async {
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  try {
    if (!context.mounted) return null;
    return await Navigator.of(context).push<(Uint8List, Color)>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (pad) => Scaffold(
          body: SafeArea(
            child: DkSignaturePad(
              onCancel: () => Navigator.of(pad).pop(),
              onSave: (png, ink) => Navigator.of(pad).pop((png, ink)),
            ),
          ),
        ),
      ),
    );
  } finally {
    // Every orientation again (the app's default).
    await SystemChrome.setPreferredOrientations(const []);
  }
}

/// The pad's ink as the store keeps it.
SignatureInk inkOf(Color ink) =>
    ink == const DkMarkup().ink ? SignatureInk.blue : SignatureInk.black;

/// The Signatures sheet's switches (DK-0326), in [prefsProvider].
const signAddDateKey = 'sign.addDate',
    signInitialsKey = 'sign.initialsEveryPage';

/// "Your signatures" (DK-0326; UI spec §17.3, design `08-sign/sign-list`,
/// `sign-empty`): a medium sheet with the saved signatures in two columns,
/// a dashed "Add signature" card, and the switches "Add date next to
/// signature" · "Initials on every page". Empty: ILL-15 with Add signature.
/// Tapping a signature returns it (the caller places it, DK-0328); a long
/// press removes it after asking. [openPad] draws a new one (tests replace
/// it).
Future<(SavedSignature, Uint8List)?> showSignaturesSheet(
  BuildContext context, {
  Future<(Uint8List, Color)?> Function(BuildContext) openPad = openSignaturePad,
}) {
  final l = AppLocalizations.of(context);
  return showDkSheet<(SavedSignature, Uint8List)>(
    context,
    title: l.sign_sheet_title,
    showClose: true,
    detent: DkSheetDetent.medium,
    body: _SignaturesSheet(openPad: openPad),
  );
}

class _SignaturesSheet extends ConsumerWidget {
  const _SignaturesSheet({required this.openPad});

  final Future<(Uint8List, Color)?> Function(BuildContext) openPad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final saved = [
      for (final s in ref.watch(signaturesProvider).value ?? const [])
        if (s.$1.kind == SignatureKind.signature) s,
    ];
    final prefs = ref.watch(prefsProvider).value ?? const {};
    final addDate = prefs[signAddDateKey] == true;
    final initials = prefs[signInitialsKey] == true;
    final settings = ref.read(prefsProvider.notifier);

    // Read before any await: the sheet may be gone by then (DK-1083).
    final signatures = ref.read(signaturesProvider.notifier);
    Future<void> guarded(Future<void> Function() action) async {
      try {
        await action();
      } catch (_) {
        if (context.mounted) showDkToast(context, l.error_unexpected_short);
      }
    }

    Future<void> add() async {
      final drawn = await openPad(context);
      if (drawn == null) return;
      await guarded(
        () =>
            signatures.add(SignatureKind.signature, drawn.$1, inkOf(drawn.$2)),
      );
    }

    final toggles = DkSettingsGroup(
      children: [
        DkSettingsRow(
          title: l.sign_add_date,
          trailing: DkSwitch(
            value: addDate,
            onChanged: (v) => settings.set(signAddDateKey, v),
          ),
          onTap: () => settings.set(signAddDateKey, !addDate),
        ),
        DkSettingsRow(
          title: l.sign_initials_every_page,
          trailing: DkSwitch(
            value: initials,
            onChanged: (v) => settings.set(signInitialsKey, v),
          ),
          onTap: () => settings.set(signInitialsKey, !initials),
        ),
      ],
    );

    if (saved.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DkEmptyStates.signatures(context, onAdd: add),
          toggles,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final width = (box.maxWidth - t.space.m) / 2;
            final height = DkSignatureCard.size.height;
            return Wrap(
              spacing: t.space.m,
              runSpacing: t.space.m,
              children: [
                for (final s in saved)
                  SizedBox(
                    width: width,
                    height: height,
                    child: DkSignatureCard(
                      signature: Image.memory(s.$2),
                      onTap: () => Navigator.of(context).pop(s),
                      onDelete: () async {
                        if (await confirmDk(
                          context,
                          DkConfirmation.removeSignature,
                        )) {
                          await guarded(() => signatures.delete(s.$1.id));
                        }
                      },
                    ),
                  ),
                SizedBox(
                  width: width,
                  height: height,
                  child: Semantics(
                    button: true,
                    label: l.sign_pad_title,
                    excludeSemantics: true,
                    onTap: add,
                    child: DkTappable(
                      onTap: add,
                      radius: t.radius.s,
                      builder: (context, pressed) => CustomPaint(
                        painter: DkDashedBorder(
                          c.outlineStrong,
                          radius: BorderRadius.circular(t.radius.s),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: t.space.xs,
                          children: [
                            DkIcon(DkIcons.add, color: c.primary),
                            Flexible(
                              child: Text(
                                l.sign_pad_title,
                                style: t.text.titleS.copyWith(color: c.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        SizedBox(height: t.space.m),
        toggles,
      ],
    );
  }
}
