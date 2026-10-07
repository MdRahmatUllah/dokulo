// The C names, as in qpdf's headers.
// ignore_for_file: non_constant_identifier_names

/// The qpdf C functions we call (qpdfjob-c.h, qpdflogger-c.h, qpdf-c.h):
/// one JSON job per operation, plus a few checks.
@DefaultAsset('package:qpdf_ffi/src/bindings.dart')
library;

import 'dart:ffi';

final class QpdfJob extends Opaque {}

final class QpdfLogger extends Opaque {}

final class QpdfData extends Opaque {}

final class QpdfError extends Opaque {}

/// `qpdf_log_fn_t`: receives log text; returns 0.
typedef LogFn = Int Function(Pointer<Char> data, Size len, Pointer<Void> udata);

// qpdfjob-c.h
@Native<Pointer<QpdfJob> Function()>()
external Pointer<QpdfJob> qpdfjob_init();

@Native<Void Function(Pointer<Pointer<QpdfJob>>)>()
external void qpdfjob_cleanup(Pointer<Pointer<QpdfJob>> job);

@Native<Int Function(Pointer<QpdfJob>, Pointer<Char>)>()
external int qpdfjob_initialize_from_json(
  Pointer<QpdfJob> job,
  Pointer<Char> json,
);

@Native<Void Function(Pointer<QpdfJob>, Pointer<QpdfLogger>)>()
external void qpdfjob_set_logger(
  Pointer<QpdfJob> job,
  Pointer<QpdfLogger> logger,
);

@Native<Int Function(Pointer<QpdfJob>)>()
external int qpdfjob_run(Pointer<QpdfJob> job);

// qpdflogger-c.h
@Native<Pointer<QpdfLogger> Function()>()
external Pointer<QpdfLogger> qpdflogger_create();

@Native<Void Function(Pointer<Pointer<QpdfLogger>>)>()
external void qpdflogger_cleanup(Pointer<Pointer<QpdfLogger>> logger);

/// `dest` is `qpdf_log_dest_e`: 3 discards, 4 sends to [fn].
@Native<
  Void Function(
    Pointer<QpdfLogger>,
    Int,
    Pointer<NativeFunction<LogFn>>,
    Pointer<Void>,
  )
>()
external void qpdflogger_set_info(
  Pointer<QpdfLogger> logger,
  int dest,
  Pointer<NativeFunction<LogFn>> fn,
  Pointer<Void> udata,
);

@Native<
  Void Function(
    Pointer<QpdfLogger>,
    Int,
    Pointer<NativeFunction<LogFn>>,
    Pointer<Void>,
  )
>()
external void qpdflogger_set_warn(
  Pointer<QpdfLogger> logger,
  int dest,
  Pointer<NativeFunction<LogFn>> fn,
  Pointer<Void> udata,
);

@Native<
  Void Function(
    Pointer<QpdfLogger>,
    Int,
    Pointer<NativeFunction<LogFn>>,
    Pointer<Void>,
  )
>()
external void qpdflogger_set_error(
  Pointer<QpdfLogger> logger,
  int dest,
  Pointer<NativeFunction<LogFn>> fn,
  Pointer<Void> udata,
);

// qpdf-c.h
@Native<Pointer<QpdfData> Function()>()
external Pointer<QpdfData> qpdf_init();

@Native<Void Function(Pointer<Pointer<QpdfData>>)>()
external void qpdf_cleanup(Pointer<Pointer<QpdfData>> qpdf);

@Native<Void Function(Pointer<QpdfData>)>()
external void qpdf_silence_errors(Pointer<QpdfData> qpdf);

@Native<Void Function(Pointer<QpdfData>, Int)>()
external void qpdf_set_suppress_warnings(Pointer<QpdfData> qpdf, int value);

/// Returns a `QPDF_ERROR_CODE`: 0 ok, bit 1 warnings, bit 2 errors.
@Native<Int Function(Pointer<QpdfData>, Pointer<Char>, Pointer<Char>)>()
external int qpdf_read(
  Pointer<QpdfData> qpdf,
  Pointer<Char> filename,
  Pointer<Char> password,
);

@Native<Pointer<QpdfError> Function(Pointer<QpdfData>)>()
external Pointer<QpdfError> qpdf_get_error(Pointer<QpdfData> qpdf);

@Native<Pointer<Char> Function(Pointer<QpdfData>, Pointer<QpdfError>)>()
external Pointer<Char> qpdf_get_error_full_text(
  Pointer<QpdfData> qpdf,
  Pointer<QpdfError> error,
);

/// `qpdf_error_code_e`: 4 password, 5 damaged PDF, … (Constants.h).
@Native<Int Function(Pointer<QpdfData>, Pointer<QpdfError>)>()
external int qpdf_get_error_code(
  Pointer<QpdfData> qpdf,
  Pointer<QpdfError> error,
);

@Native<Pointer<Char> Function(Pointer<QpdfData>)>()
external Pointer<Char> qpdf_get_pdf_version(Pointer<QpdfData> qpdf);

@Native<Int Function(Pointer<QpdfData>)>()
external int qpdf_is_encrypted(Pointer<QpdfData> qpdf);

@Native<Int Function(Pointer<QpdfData>)>()
external int qpdf_is_linearized(Pointer<QpdfData> qpdf);

@Native<Int Function(Pointer<QpdfData>)>()
external int qpdf_get_num_pages(Pointer<QpdfData> qpdf);
