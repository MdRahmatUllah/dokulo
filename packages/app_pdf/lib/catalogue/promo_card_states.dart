import 'package:flutter/material.dart';

import '../components/dk_icon.dart';
import '../components/dk_promo_cards.dart';
import '../theme/dk_tokens.dart';

/// DkContinueCard (a scan, a tool job) and DkProCard (Home with ×, Me
/// without).
class DkPromoCardsGallery extends StatelessWidget {
  const DkPromoCardsGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    void tap() {}
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: t.space.m,
      children: [
        DkContinueCard(
          icon: DkIcons.scan,
          title: 'Continue your scan',
          sub: '3 pages · 2 min ago',
          action: 'Continue',
          onAction: tap,
          onDismiss: tap,
        ),
        DkContinueCard(
          icon: DkIcons.tool('compress'),
          title: 'Compressed: Rechnung.pdf',
          sub: '1.9 MB · Today 14:32',
          action: 'Open',
          onAction: tap,
          onDismiss: tap,
        ),
        DkProCard(onOpen: tap, onDismiss: tap),
        DkProCard(onOpen: tap),
      ],
    );
  }
}
