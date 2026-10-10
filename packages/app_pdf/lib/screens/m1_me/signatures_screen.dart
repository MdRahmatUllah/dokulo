import 'dart:typed_data';

import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_toast.dart';
import '../../components/dk_banner.dart';
import '../../components/dk_box_frame.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_signature_card.dart';
import '../../components/dk_tappable.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/formats.dart';
import '../../patterns/dk_confirmations.dart';
import '../../providers/signature_providers.dart';
import '../../theme/dk_tokens.dart';
import '../sign/signatures_sheet.dart';

/// Me → Signatures (DK-0325; design `22-me-settings/me-signatures`): the
/// saved signatures and initials, two columns each, with the ink and the
/// date under each ("Blue ink · added 2 Oct") and a dashed "Add" tile; a
/// long press removes one, after "Remove this signature?". They are stored
/// encrypted (the banner says so).
class SignaturesScreen extends ConsumerWidget {
  const SignaturesScreen({super.key, this.addSignature = openSignaturePad});

  /// Draws a new one: the signature pad, full screen. Tests replace it.
  final Future<(Uint8List, Color)?> Function(BuildContext) addSignature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final saved = ref.watch(signaturesProvider).value ?? const [];
    final locale = Localizations.localeOf(context).toLanguageTag();

    // The notifier is read before any await: the screen may be gone by
    // then (DK-1083); a failure says so instead of losing the signature.
    final signatures = ref.read(signaturesProvider.notifier);
    Future<void> guarded(Future<void> Function() action) async {
      try {
        await action();
      } catch (_) {
        if (context.mounted) showDkToast(context, l.error_unexpected_short);
      }
    }

    Future<void> add(SignatureKind kind) async {
      final result = await addSignature(context);
      if (result == null) return;
      final (png, ink) = result;
      await guarded(() => signatures.add(kind, png, inkOf(ink)));
    }

    Future<void> remove(int id) async {
      if (await confirmDk(context, DkConfirmation.removeSignature)) {
        await guarded(() => signatures.delete(id));
      }
    }

    Widget section(SignatureKind kind) {
      final mine = [
        for (final s in saved)
          if (s.$1.kind == kind) s,
      ];
      final addLabel = kind == SignatureKind.signature
          ? l.sign_pad_title
          : l.me_add_initials;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              t.space.l,
              t.space.xl,
              t.space.l,
              t.space.s,
            ),
            child: Semantics(
              header: true,
              child: Text(
                kind == SignatureKind.signature
                    ? l.me_signatures
                    : l.me_initials,
                style: t.text.labelM.copyWith(color: c.textSecondary),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.l),
            child: LayoutBuilder(
              builder: (context, box) {
                final width = (box.maxWidth - t.space.m) / 2;
                return Wrap(
                  spacing: t.space.m,
                  runSpacing: t.space.m,
                  children: [
                    for (final (s, png) in mine)
                      SizedBox(
                        width: width,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: t.space.xs,
                          children: [
                            SizedBox(
                              height: DkSignatureCard.size.height,
                              width: width,
                              child: DkSignatureCard(
                                signature: Image.memory(png),
                                onDelete: () => remove(s.id),
                              ),
                            ),
                            Text(
                              l.me_signature_meta(
                                s.ink == SignatureInk.blue
                                    ? l.markup_ink
                                    : l.markup_black,
                                formatDate(s.created, locale),
                              ),
                              style: t.text.caption.copyWith(
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: width,
                      height: DkSignatureCard.size.height,
                      child: Semantics(
                        button: true,
                        label: addLabel,
                        excludeSemantics: true,
                        onTap: () => add(kind),
                        child: DkTappable(
                          onTap: () => add(kind),
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
                                    addLabel,
                                    style: t.text.titleS.copyWith(
                                      color: c.primary,
                                    ),
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
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: DkTopBar(title: l.me_signatures),
      body: ListView(
        padding: EdgeInsets.only(bottom: t.space.xl),
        children: [
          section(SignatureKind.signature),
          section(SignatureKind.initials),
          Padding(
            padding: EdgeInsets.fromLTRB(t.space.l, t.space.xl, t.space.l, 0),
            child: DkBanner(text: l.me_signatures_banner),
          ),
        ],
      ),
    );
  }
}
