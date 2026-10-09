import 'package:flutter/material.dart';

import '../components/dk_banner.dart';
import '../components/dk_icon.dart';
import '../l10n/app_localizations.dart';

/// The global states board's banners (UI spec §32.2; DK-0622), one per
/// variant: info (scans without text), error (a purchase that failed) and
/// Pro (the free try). The warning is [DkPermissionBanner]; toasts with an
/// action are `showDkUndo` and `showDkToast`.
abstract final class DkBanners {
  /// Info: [count] scans have no searchable text yet · Make searchable.
  static Widget noSearchableText(
    BuildContext context, {
    required int count,
    required VoidCallback onMakeSearchable,
  }) {
    final l = AppLocalizations.of(context);
    return DkBanner(
      icon: DkIcons.noText,
      text: l.banner_no_text(count),
      action: l.banner_make_searchable,
      onAction: onMakeSearchable,
    );
  }

  /// Error: the store didn't complete the purchase; nobody was charged.
  static Widget purchaseFailed(BuildContext context) => DkBanner(
    variant: DkBannerVariant.error,
    text: AppLocalizations.of(context).banner_purchase_failed,
  );

  /// Pro: a Pro tool's free try.
  static Widget proFreeTry(BuildContext context) => DkBanner(
    variant: DkBannerVariant.pro,
    text: AppLocalizations.of(context).banner_pro_free_try,
  );
}
