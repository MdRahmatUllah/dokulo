import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';

/// The spinner's two sizes (UI spec §11.7).
enum DkSpinnerSize {
  small(20),
  large(32);

  const DkSpinnerSize(this.dp);
  final double dp;
}

/// The platform's activity indicator in `color.primary` (UI spec §11.7;
/// DK-0200): iOS's petals, Android's ring. Only inside buttons and for
/// waits under 2 s in sheets; longer work shows progress (DkProgressSheet).
/// [color] for a spinner on a filled button (its text colour).
///
/// Its "Loading" is not a container: inside a button it joins the button's
/// label ("Save, Loading"), which is what a screen reader should hear.
class DkLoadingSpinner extends StatelessWidget {
  const DkLoadingSpinner({
    super.key,
    this.size = DkSpinnerSize.small,
    this.color,
  });

  final DkSpinnerSize size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? context.tokens.color.primary;
    final apple = switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    return Semantics(
      label: AppLocalizations.of(context).common_loading,
      child: SizedBox.square(
        dimension: size.dp,
        child: apple
            ? CupertinoActivityIndicator(radius: size.dp / 2, color: ink)
            : CircularProgressIndicator(
                strokeWidth: size == DkSpinnerSize.small ? 2 : 3,
                color: ink,
              ),
      ),
    );
  }
}
