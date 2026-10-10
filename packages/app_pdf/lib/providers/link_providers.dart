import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'link_providers.g.dart';

/// Opens a web address in the user's browser, after V1 asked (DK-1088).
/// True when something opened it. Tests override it.
typedef LinkOpener = Future<bool> Function(Uri url);

/// The platform side, channel `dokulo/links`: Android's ACTION_VIEW, iOS's
/// `UIApplication.open`. No plugin for one call.
@Riverpod(keepAlive: true)
LinkOpener linkOpener(Ref ref) => (url) async {
  try {
    return await const MethodChannel('dokulo/links')
            .invokeMethod<bool>('open', url.toString()) ??
        false;
  } on MissingPluginException {
    return false;
  }
};
