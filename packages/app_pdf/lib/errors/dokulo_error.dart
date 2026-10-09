import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';

import '../l10n/app_localizations.dart';

/// The situations of the error catalogue (UI spec §26.3; docs/errors.md).
enum DkErrorSituation {
  locked('DK-0100'),
  damaged('DK-0110'),
  notEnoughStorage('DK-0120'),
  tooLarge('DK-0130'),
  unsupportedForm('DK-0140'),
  modelMissing('DK-0150'),
  lowMemory('DK-0160'),
  cancelled('DK-0170'),
  offline('DK-0180'),
  unexpected('DK-0190');

  const DkErrorSituation(this.code);

  /// Shown with "Something went wrong" and in a sent report; never alone.
  final String code;
}

/// What the user can do about an error: one action per situation, none
/// after a cancel, three after an unexpected failure (§26.3).
enum DkRecovery {
  enterPassword,
  tryRepair,
  manageStorage,
  splitFirst,
  openReadOnly,
  download,
  tryAgain,
  skipPage,
  sendReport;

  String label(AppLocalizations l) => switch (this) {
    enterPassword => l.error_action_enter_password,
    tryRepair => l.error_action_try_repair,
    manageStorage => l.error_action_manage_storage,
    splitFirst => l.error_action_split_first,
    openReadOnly => l.error_action_open_read_only,
    download => l.common_download,
    tryAgain => l.common_try_again,
    skipPage => l.error_action_skip_page,
    sendReport => l.error_action_send_report,
  };
}

/// Every failure the user sees (DK-0609): its situation and code, the page
/// it happened on, the catalogue's localised message and its recovery
/// actions. Engine and job exceptions all map to it ([DokuloError.from]);
/// screens show it inline where it happens (a field error, a banner, the
/// progress sheet's failure state), never as a generic "Error" modal.
class DokuloError implements Exception {
  const DokuloError(
    this.situation, {
    this.page,
    this.neededBytes,
    this.modelBytes,
    this.detail = '',
  });

  final DkErrorSituation situation;

  /// The 0-based page it happened on, if known ("on page 14").
  final int? page;

  /// Not enough storage: how much the job needs ("needs about 120 MB").
  final int? neededBytes;

  /// Model missing: the model's download size ("440 MB").
  final int? modelBytes;

  /// For logs and the user-sent report; never shown as the message.
  final String detail;

  String get code => situation.code;

  /// Maps any thrown error to the catalogue. Failures from a worker isolate
  /// arrive as text ([JobFailed]), so engine exceptions are recognised by
  /// the name in their message as well as by type; anything unknown is
  /// [DkErrorSituation.unexpected].
  static DokuloError from(Object error) {
    switch (error) {
      case DokuloError e:
        return e;
      case DocError e:
        return DokuloError(
          _byKind[e.kind]!,
          page: e.page,
          neededBytes: e.bytes,
          detail: '$e',
        );
      case JobCancelled():
        return const DokuloError(DkErrorSituation.cancelled);
      case FileSystemException e when _noSpace(e.osError?.errorCode):
        return DokuloError(DkErrorSituation.notEnoughStorage, detail: '$e');
      case OutOfMemoryError():
        return const DokuloError(DkErrorSituation.tooLarge);
    }
    final text = error is JobFailed ? error.message : '$error';
    for (final (pattern, situation) in _byText) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final page = match.groupNames.contains('page')
            ? int.tryParse(match.namedGroup('page') ?? '')
            : null;
        return DokuloError(situation, page: page, detail: text);
      }
    }
    return DokuloError(DkErrorSituation.unexpected, detail: text);
  }

  static const _byKind = {
    DocErrorKind.locked: DkErrorSituation.locked,
    DocErrorKind.damaged: DkErrorSituation.damaged,
    DocErrorKind.notEnoughStorage: DkErrorSituation.notEnoughStorage,
    DocErrorKind.tooLarge: DkErrorSituation.tooLarge,
    DocErrorKind.unsupportedForm: DkErrorSituation.unsupportedForm,
    DocErrorKind.cancelled: DkErrorSituation.cancelled,
    DocErrorKind.unexpected: DkErrorSituation.unexpected,
  };

  /// ENOSPC on POSIX (28) and ERROR_DISK_FULL on Windows (112).
  static bool _noSpace(int? code) => code == 28 || code == 112;

  /// Engine exceptions by their `toString()`: DocError(kind, page n: …),
  /// QpdfException(kind), OcrException(failure), WebToPdfException(error),
  /// VisionOcrException(error), and ai_core's offline guard.
  static final _byText = <(RegExp, DkErrorSituation)>[
    for (final MapEntry(key: kind, value: situation) in _byKind.entries)
      (RegExp('DocError\\(${kind.name}(, page (?<page>\\d+))?'), situation),
    (RegExp(r'QpdfException\(password\)'), DkErrorSituation.locked),
    (RegExp(r'QpdfException\(damaged\)'), DkErrorSituation.damaged),
    (RegExp(r'OcrException\(notAnImage\)'), DkErrorSituation.damaged),
    (RegExp(r'VisionOcrException\(notAnImage\)'), DkErrorSituation.damaged),
    (RegExp(r'WebToPdfException\(loadFailed\)'), DkErrorSituation.offline),
    (RegExp(r'OutOfMemoryError|Out of Memory'), DkErrorSituation.tooLarge),
  ];

  /// The catalogue's message, in the user's language.
  String title(AppLocalizations l) => switch (situation) {
    DkErrorSituation.locked => l.error_locked,
    DkErrorSituation.damaged => l.error_damaged,
    DkErrorSituation.notEnoughStorage =>
      neededBytes == null
          ? l.error_storage
          : l.error_storage_needs(_megabytes(neededBytes!)),
    DkErrorSituation.tooLarge => l.error_too_large,
    DkErrorSituation.unsupportedForm => l.error_unsupported_form,
    // ponytail: the translation model's copy (§26.3); other features' models
    // get their own line when their download screens are built (M13).
    DkErrorSituation.modelMissing => l.error_model_missing(
      _megabytes(modelBytes ?? 0),
    ),
    DkErrorSituation.lowMemory => l.error_low_memory,
    DkErrorSituation.cancelled => l.error_cancelled,
    DkErrorSituation.offline => l.error_offline,
    DkErrorSituation.unexpected =>
      page == null
          ? l.error_unexpected(code)
          : l.error_unexpected_page(page! + 1, code),
  };

  /// The recovery actions, in order (§26.3). Skip this page only where a
  /// page is known.
  List<DkRecovery> get actions => switch (situation) {
    DkErrorSituation.locked => const [DkRecovery.enterPassword],
    DkErrorSituation.damaged => const [DkRecovery.tryRepair],
    DkErrorSituation.notEnoughStorage => const [DkRecovery.manageStorage],
    DkErrorSituation.tooLarge => const [DkRecovery.splitFirst],
    DkErrorSituation.unsupportedForm => const [DkRecovery.openReadOnly],
    DkErrorSituation.modelMissing => const [DkRecovery.download],
    DkErrorSituation.lowMemory => const [DkRecovery.tryAgain],
    DkErrorSituation.cancelled => const [],
    DkErrorSituation.offline => const [DkRecovery.tryAgain],
    DkErrorSituation.unexpected => [
      DkRecovery.tryAgain,
      if (page != null) DkRecovery.skipPage,
      DkRecovery.sendReport,
    ],
  };

  static int _megabytes(int bytes) => (bytes / 1000000).ceil();

  @override
  String toString() => 'DokuloError($code ${situation.name}): $detail';
}
