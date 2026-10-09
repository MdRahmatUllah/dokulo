import 'package:flutter/material.dart';

import '../patterns/dk_banners.dart';
import '../patterns/dk_permission_banner.dart';
import '../theme/dk_tokens.dart';

/// The global states board's banners: info, warning, error, Pro (DK-0621,
/// DK-0622).
class GlobalBannersGallery extends StatelessWidget {
  const GlobalBannersGallery({super.key});

  @override
  Widget build(BuildContext context) => Column(
    spacing: context.tokens.space.m,
    children: [
      DkBanners.noSearchableText(context, count: 3, onMakeSearchable: () {}),
      DkPermissionBanner(
        permission: DkPermission.camera,
        onOpenSettings: () {},
      ),
      DkBanners.purchaseFailed(context),
      DkBanners.proFreeTry(context),
    ],
  );
}
