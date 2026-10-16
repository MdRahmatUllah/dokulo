import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_banner.dart';
import '../../components/dk_icon.dart';
import '../../l10n/app_localizations.dart';
import '../../photo_finder/photo_finder_screens.dart';
import '../../providers/prefs_providers.dart';
import '../../theme/dk_tokens.dart';

/// The prefs key of the day Dokulo first opened Home (ISO date).
const firstUseKey = 'app.firstUse';

/// The prefs key of the photo banner once it is done with: 'dismissed'
/// (×) or 'used' (Look now: the photo finder is on from then).
const photoBannerKey = 'home.photoBanner';

/// H1's "Find documents in your photos?" (DK-0252; home-photobanner): from
/// the 7th day of use, until the user dismisses it or looks (then the photo
/// finder is on and Home shows its card instead). Look now opens the photo
/// finder's intro.
class HomePhotoBanner extends ConsumerStatefulWidget {
  const HomePhotoBanner({super.key, this.now});

  /// For tests: the clock.
  final DateTime Function()? now;

  @override
  ConsumerState<HomePhotoBanner> createState() => _HomePhotoBannerState();
}

class _HomePhotoBannerState extends ConsumerState<HomePhotoBanner> {
  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(prefsProvider).value;
    if (prefs == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final first = DateTime.tryParse('${prefs[firstUseKey]}');
    if (first == null) {
      // Day one: remember it (after this frame; build doesn't write).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(prefsProvider.notifier)
              .set(firstUseKey, _now().toIso8601String());
        }
      });
    }
    final due =
        first != null && _now().difference(first) >= const Duration(days: 7);
    if (!due || prefs[photoBannerKey] != null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    void done(String why) =>
        ref.read(prefsProvider.notifier).set(photoBannerKey, why);
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(t.space.l, t.space.l, t.space.l, 0),
      sliver: SliverToBoxAdapter(
        child: DkBanner(
          icon: DkIcons.importPhotos,
          text: l.home_photo_banner,
          action: l.home_photo_banner_action,
          onAction: () {
            done('used');
            startPhotoFinder(context, ref);
          },
          onDismiss: () => done('dismissed'),
        ),
      ),
    );
  }
}
