import 'package:ai_core/ai_core.dart';
import 'package:qpdf_ffi/qpdf_ffi.dart';

import 'pdf_engine.dart';

/// qpdf for tool jobs (DK-0391): run it inside a `Lane.qpdf` job, where
/// [run] is allowed; qpdf's errors come out as the error catalogue's
/// [DocError]s (§26.3).
///
/// ```dart
/// QpdfService.run(() => Qpdf.encrypt(input, output, userPassword: pw));
/// ```
abstract final class QpdfService {
  static T run<T>(T Function() operation) {
    assertWorkerIsolate();
    try {
      return operation();
    } on QpdfException catch (e) {
      throw docErrorOf(e);
    }
  }

  /// One new PDF at [output] of [parts]' pages, in order (Merge PDF): each
  /// part is `{file, password?, range?}`, the range in qpdf's syntax
  /// ("1-3,7", `z` the last page). Links, annotations and form fields come
  /// along; outlines don't.
  static void joinPages(List<Map<String, Object?>> parts, String output) =>
      run(() => Qpdf.run({'empty': '', 'outputFile': output, 'pages': parts}));

  static DocError docErrorOf(QpdfException e) => DocError(switch (e.kind) {
    QpdfErrorKind.password => DocErrorKind.locked,
    QpdfErrorKind.damaged ||
    QpdfErrorKind.pages ||
    QpdfErrorKind.object ||
    QpdfErrorKind.linearization ||
    QpdfErrorKind.unsupported => DocErrorKind.damaged,
    QpdfErrorKind.system when e.message.toLowerCase().contains('no space') =>
      DocErrorKind.notEnoughStorage,
    _ => DocErrorKind.unexpected,
  }, detail: 'qpdf ${e.kind.name}: ${e.message}');
}
