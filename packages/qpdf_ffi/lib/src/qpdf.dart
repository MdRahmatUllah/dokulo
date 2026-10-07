import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';

/// What went wrong, as qpdf classifies it (`qpdf_error_code_e`).
enum QpdfErrorKind {
  internal,
  system,
  unsupported,
  password,
  damaged,
  pages,
  object,
  json,
  linearization,
  unknown,
}

class QpdfException implements Exception {
  QpdfException(this.kind, this.message);

  final QpdfErrorKind kind;

  /// qpdf's own text: for logs, never for the user.
  final String message;

  @override
  String toString() => 'QpdfException(${kind.name}): $message';
}

class QpdfInfo {
  const QpdfInfo({
    required this.pages,
    required this.encrypted,
    required this.linearized,
    required this.version,
  });

  final int pages;
  final bool encrypted;
  final bool linearized;

  /// "1.7", "2.0", …
  final String version;
}

/// qpdf, one call per operation. Native code: call it on a worker isolate,
/// never on the UI isolate (doc_core's QpdfService does).
abstract final class Qpdf {
  /// Runs one job in qpdf's job JSON (`qpdf --job-json-help`; option names in
  /// camelCase, flags as ""). Returns qpdf's warnings; throws [QpdfException]
  /// on an error.
  static List<String> run(Map<String, Object?> job) {
    final warnings = StringBuffer();
    final errors = StringBuffer();
    final onWarn = _sink(warnings);
    final onError = _sink(errors);
    final logger = calloc<Pointer<QpdfLogger>>()..value = qpdflogger_create();
    final handle = calloc<Pointer<QpdfJob>>()..value = qpdfjob_init();
    final json = jsonEncode(job).toNativeUtf8();
    try {
      qpdflogger_set_info(logger.value, _discard, nullptr, nullptr);
      qpdflogger_set_warn(
        logger.value,
        _custom,
        onWarn.nativeFunction,
        nullptr,
      );
      qpdflogger_set_error(
        logger.value,
        _custom,
        onError.nativeFunction,
        nullptr,
      );
      qpdfjob_set_logger(handle.value, logger.value);
      if (qpdfjob_initialize_from_json(handle.value, json.cast()) != 0) {
        throw QpdfException(QpdfErrorKind.json, errors.toString().trim());
      }
      // 0 success, 2 errors, 3 warnings only (QPDFJob::EXIT_*).
      if (qpdfjob_run(handle.value) == 2) {
        throw QpdfException(
          _kindOf(errors.toString()),
          errors.toString().trim(),
        );
      }
      return const LineSplitter()
          .convert(warnings.toString())
          .where((l) => l.trim().isNotEmpty)
          .toList();
    } finally {
      calloc.free(json);
      qpdfjob_cleanup(handle);
      qpdflogger_cleanup(logger);
      calloc
        ..free(handle)
        ..free(logger);
      onWarn.close();
      onError.close();
    }
  }

  /// Opens [path] and reads its basic facts.
  static QpdfInfo inspect(String path, {String? password}) {
    final qpdf = calloc<Pointer<QpdfData>>()..value = qpdf_init();
    final file = path.toNativeUtf8();
    final secret = password?.toNativeUtf8();
    try {
      qpdf_silence_errors(qpdf.value);
      qpdf_set_suppress_warnings(qpdf.value, 1);
      if (qpdf_read(qpdf.value, file.cast(), (secret ?? nullptr).cast()) & 2 !=
          0) {
        final error = qpdf_get_error(qpdf.value);
        final code = qpdf_get_error_code(qpdf.value, error);
        throw QpdfException(
          _kinds[code] ?? QpdfErrorKind.unknown,
          qpdf_get_error_full_text(
            qpdf.value,
            error,
          ).cast<Utf8>().toDartString(),
        );
      }
      return QpdfInfo(
        pages: qpdf_get_num_pages(qpdf.value),
        encrypted: qpdf_is_encrypted(qpdf.value) != 0,
        linearized: qpdf_is_linearized(qpdf.value) != 0,
        version: qpdf_get_pdf_version(qpdf.value).cast<Utf8>().toDartString(),
      );
    } finally {
      calloc.free(file);
      if (secret != null) calloc.free(secret);
      qpdf_cleanup(qpdf);
      calloc.free(qpdf);
    }
  }

  /// AES-256 (R6) with [userPassword] to open; [ownerPassword] defaults to it.
  static List<String> encrypt(
    String input,
    String output, {
    required String userPassword,
    String? ownerPassword,
  }) => run({
    'inputFile': input,
    'outputFile': output,
    'encrypt': {
      'userPassword': userPassword,
      'ownerPassword': ownerPassword ?? userPassword,
      '256bit': {},
    },
  });

  /// Removes the encryption, with the password the user knows.
  static List<String> decrypt(
    String input,
    String output, {
    required String password,
  }) => run({
    'inputFile': input,
    'password': password,
    'outputFile': output,
    'decrypt': '',
  });

  /// Rewrites the file; qpdf rebuilds what it can (a broken cross-reference
  /// table, bad stream lengths) while it reads.
  static List<String> repair(String input, String output, {String? password}) =>
      run({'inputFile': input, 'password': ?password, 'outputFile': output});

  /// Compresses the structure: object streams, compressed streams, flate
  /// recompressed at the best level. Images are DK-0392's job.
  static List<String> compressStructure(
    String input,
    String output, {
    String? password,
  }) => run({
    'inputFile': input,
    'password': ?password,
    'outputFile': output,
    'objectStreams': 'generate',
    'compressStreams': 'y',
    'recompressFlate': '',
    'compressionLevel': '9',
  });

  /// Linearises for fast web view.
  static List<String> linearize(
    String input,
    String output, {
    String? password,
  }) => run({
    'inputFile': input,
    'password': ?password,
    'outputFile': output,
    'linearize': '',
  });

  /// Puts the pages of [stamp] over (or under) the pages of [input]: page n on
  /// page n, or with [repeat] = "1" the first stamp page on every page.
  static List<String> overlay(
    String input,
    String stamp,
    String output, {
    bool underlay = false,
    String? repeat,
  }) => run({
    'inputFile': input,
    'outputFile': output,
    underlay ? 'underlay' : 'overlay': [
      {'file': stamp, 'repeat': ?repeat},
    ],
  });

  /// Writes the pages in [range] (qpdf syntax: "1-3,7", "z" is the last page)
  /// to a new file.
  static List<String> extract(
    String input,
    String range,
    String output, {
    String? password,
  }) => run({
    'inputFile': input,
    'password': ?password,
    'outputFile': output,
    'pages': [
      {'file': input, 'password': ?password, 'range': range},
    ],
  });

  /// Checks the structure; throws [QpdfException] when it is broken.
  static List<String> check(String input, {String? password}) =>
      run({'inputFile': input, 'password': ?password, 'check': ''});
}

const _discard = 3; // qpdf_log_dest_discard
const _custom = 4; // qpdf_log_dest_custom

/// A log destination that appends to [to]; qpdf calls it synchronously on
/// this thread, so an isolate-local callable is enough.
NativeCallable<LogFn> _sink(StringBuffer to) =>
    NativeCallable<LogFn>.isolateLocal((
      Pointer<Char> data,
      int length,
      Pointer<Void> _,
    ) {
      to.write(
        utf8.decode(
          data.cast<Uint8>().asTypedList(length),
          allowMalformed: true,
        ),
      );
      return 0;
    }, exceptionalReturn: 1);

const _kinds = {
  1: QpdfErrorKind.internal,
  2: QpdfErrorKind.system,
  3: QpdfErrorKind.unsupported,
  4: QpdfErrorKind.password,
  5: QpdfErrorKind.damaged,
  6: QpdfErrorKind.pages,
  7: QpdfErrorKind.object,
  8: QpdfErrorKind.json,
  9: QpdfErrorKind.linearization,
};

/// A job reports errors as text only; these are qpdf's wordings.
QpdfErrorKind _kindOf(String text) {
  final t = text.toLowerCase();
  if (t.contains('invalid password')) return QpdfErrorKind.password;
  if (t.contains('no such file') ||
      t.contains("can't open") ||
      t.contains('no space left')) {
    return QpdfErrorKind.system;
  }
  if (t.contains('damaged') ||
      t.contains('xref') ||
      t.contains('trailer') ||
      t.contains('not a pdf') ||
      t.contains("can't find pdf header") ||
      t.contains('unable to find')) {
    return QpdfErrorKind.damaged;
  }
  return QpdfErrorKind.unknown;
}
