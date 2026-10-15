import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mail_providers.g.dart';

/// Opens a draft in the user's mail app: "Send report by email" (DK-1080,
/// DK-0011). True when a mail app took it. Tests override it.
typedef MailComposer = Future<bool> Function(Uri mailto);

/// The platform side, channel `dokulo/mail`: Android's ACTION_SENDTO,
/// iOS's `UIApplication.open`. No plugin for one call.
@Riverpod(keepAlive: true)
MailComposer mailComposer(Ref ref) => (mailto) async {
  try {
    return await const MethodChannel('dokulo/mail')
            .invokeMethod<bool>('compose', mailto.toString()) ??
        false;
  } on MissingPluginException {
    return false;
  }
};
