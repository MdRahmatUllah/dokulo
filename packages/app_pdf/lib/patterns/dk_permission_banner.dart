import 'package:flutter/material.dart';

import '../components/dk_banner.dart';
import '../components/dk_icon.dart';
import '../l10n/app_localizations.dart';

/// The permissions Dokulo asks for (UI spec §26.4). Network is never asked:
/// the app works offline.
enum DkPermission { camera, photos, photosAdd, notifications, biometrics }

/// A denied permission at the point of use (UI spec §26.4; DK-0621): an
/// inline warning DkBanner saying what doesn't work, with "Open settings".
/// The app never asks again by itself; only the system settings change it.
class DkPermissionBanner extends StatelessWidget {
  const DkPermissionBanner({
    super.key,
    required this.permission,
    required this.onOpenSettings,
  });

  final DkPermission permission;

  /// Opens this app's page in the system settings.
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DkBanner(
      variant: DkBannerVariant.warning,
      // The camera's own icon, as the global states board.
      icon: permission == DkPermission.camera ? DkIcons.cameraOff : null,
      text: switch (permission) {
        DkPermission.camera => l.permission_off_camera,
        DkPermission.photos => l.permission_off_photos,
        DkPermission.photosAdd => l.permission_off_photos_add,
        DkPermission.notifications => l.permission_off_notifications,
        DkPermission.biometrics => l.permission_off_biometrics,
      },
      action: l.common_open_settings,
      onAction: onOpenSettings,
    );
  }
}
