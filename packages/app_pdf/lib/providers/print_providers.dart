import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'print_providers.g.dart';

/// Opens the system's print dialog for the PDF at a path (V1's Print,
/// DK-0295). True when the dialog opened (iOS: when the job was sent).
/// Tests override it.
typedef PdfPrinter = Future<bool> Function(String path, String name);

/// The platform side, channel `dokulo/print`: Android's PrintManager, iOS's
/// UIPrintInteractionController. No plugin for one call.
@Riverpod(keepAlive: true)
PdfPrinter pdfPrinter(Ref ref) => (path, name) async {
  try {
    return await const MethodChannel('dokulo/print')
            .invokeMethod<bool>('pdf', {'path': path, 'name': name}) ??
        false;
  } on MissingPluginException {
    return false;
  }
};
