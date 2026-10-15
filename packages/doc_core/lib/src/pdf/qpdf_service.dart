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

  /// Whether [path] is encrypted; `locked` when [password] doesn't open it.
  static bool isEncrypted(String path, {String? password}) =>
      run(() => Qpdf.inspect(path, password: password).encrypted);

  /// AES-256 (R6) with [password] to open (Add password). Each permission
  /// left off is enforced by an owner password nobody knows ([owner]).
  static void protect(
    String input,
    String output, {
    required String password,
    required String owner,
    bool printing = true,
    bool copying = true,
    bool editing = false,
    String? currentPassword,
  }) => run(
    () => Qpdf.run({
      'inputFile': input,
      'password': ?currentPassword,
      'outputFile': output,
      'encrypt': {
        'userPassword': password,
        'ownerPassword': printing && copying && editing ? password : owner,
        '256bit': {
          'print': printing ? 'full' : 'none',
          'extract': copying ? 'y' : 'n',
          'modify': editing ? 'all' : 'none',
        },
      },
    }),
  );

  /// Removes the encryption with the [password] the user knows.
  static void unlock(String input, String output, {required String password}) =>
      run(() => Qpdf.decrypt(input, output, password: password));

  /// Rewrites [input]; qpdf rebuilds what it can (a broken cross-reference
  /// table, bad stream lengths) while it reads. Returns qpdf's warnings:
  /// what it found and fixed.
  static List<String> repair(String input, String output, {String? password}) =>
      run(() => Qpdf.repair(input, output, password: password));

  /// [stamp]'s page n over (or, [underlay], under) [input]'s page n, as a
  /// new file (page numbers, watermarks; [PdfStamp]).
  static void stamp(
    String input,
    String stamp,
    String output, {
    bool underlay = false,
    String? password,
  }) => run(
    () => Qpdf.overlay(
      input,
      stamp,
      output,
      underlay: underlay,
      password: password,
    ),
  );

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
