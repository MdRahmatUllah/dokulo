import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as fpdf;

// Raw PDFium for the edits pdfrx has no API for (annotations, crop boxes).
// Call these only on pdfrx's worker (via compute).

/// Loads [path] (from memory: PDFium's path handling isn't UTF-8-safe
/// everywhere) and runs [body] on it.
T withRawDocument<T>(
  String path,
  String? password,
  T Function(fpdf.PDFium pdfium, fpdf.FPDF_DOCUMENT doc, Arena arena) body,
) {
  final pdfium = fpdf.getPdfium();
  return using((arena) {
    final bytes = File(path).readAsBytesSync();
    final buffer = arena<Uint8>(bytes.length);
    buffer.asTypedList(bytes.length).setAll(0, bytes);
    final doc = pdfium.FPDF_LoadMemDocument64(
      buffer.cast(),
      bytes.length,
      password == null
          ? nullptr
          : password.toNativeUtf8(allocator: arena).cast(),
    );
    if (doc == nullptr) {
      throw StateError(
        'FPDF_LoadMemDocument64 failed: ${pdfium.FPDF_GetLastError()}',
      );
    }
    try {
      return body(pdfium, doc, arena);
    } finally {
      pdfium.FPDF_CloseDocument(doc);
    }
  });
}

final _saved = BytesBuilder(copy: false);

int _writeBlock(
  Pointer<fpdf.FPDF_FILEWRITE> self,
  Pointer<Void> data,
  int size,
) {
  _saved.add(Uint8List.fromList(data.cast<Uint8>().asTypedList(size)));
  return 1;
}

/// The whole document, rewritten (never incremental).
Uint8List saveRawDocument(fpdf.PDFium pdfium, fpdf.FPDF_DOCUMENT doc) {
  final write =
      NativeCallable<
        Int Function(Pointer<fpdf.FPDF_FILEWRITE>, Pointer<Void>, UnsignedLong)
      >.isolateLocal(_writeBlock, exceptionalReturn: 0);
  final fw = calloc<fpdf.FPDF_FILEWRITE>()
    ..ref.version = 1
    ..ref.WriteBlock = write.nativeFunction;
  try {
    _saved.clear();
    if (pdfium.FPDF_SaveAsCopy(doc, fw, fpdf.FPDF_NO_INCREMENTAL) == 0) {
      throw StateError('FPDF_SaveAsCopy failed');
    }
    return _saved.takeBytes();
  } finally {
    calloc.free(fw);
    write.close();
  }
}
