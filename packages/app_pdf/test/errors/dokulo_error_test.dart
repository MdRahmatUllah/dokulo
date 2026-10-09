import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:app_pdf/errors/dokulo_error.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

/// The shared sample corpus (DK-0023), from the repo root.
String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

Future<DokuloError> thrownBy(Future<void> Function() body) async {
  try {
    await body();
  } catch (e) {
    return DokuloError.from(e);
  }
  fail('nothing was thrown');
}

void main() {
  setUpAll(pdfrxInitialize);
  final en = lookupAppLocalizations(const Locale('en'));
  final de = lookupAppLocalizations(const Locale('de'));

  test('every engine error kind maps, and every situation has its own code '
      '(DK-0609)', () {
    for (final kind in DocErrorKind.values) {
      final e = DokuloError.from(DocError(kind));
      expect(e.situation.name, kind.name, reason: '$kind');
    }
    final codes = DkErrorSituation.values.map((s) => s.code).toSet();
    expect(codes, hasLength(DkErrorSituation.values.length));
    expect(codes.every(RegExp(r'^DK-\d{4}$').hasMatch), isTrue);
  });

  test(
    'failures from a worker arrive as text and still map, with the page',
    () {
      DkErrorSituation of(String message) =>
          DokuloError.from(JobFailed(message, '')).situation;
      expect(of('DocError(locked: x.pdf)'), DkErrorSituation.locked);
      expect(of('QpdfException(password): wrong'), DkErrorSituation.locked);
      expect(of('QpdfException(damaged): xref'), DkErrorSituation.damaged);
      expect(of('OcrException(notAnImage)'), DkErrorSituation.damaged);
      expect(of('WebToPdfException(loadFailed)'), DkErrorSituation.offline);
      expect(of('StateError: who knows'), DkErrorSituation.unexpected);
      final onPage = DokuloError.from(
        JobFailed('DocError(unexpected, page 13: PDFium 7)', ''),
      );
      expect(onPage.page, 13);
    },
  );

  test('a full disk is "Not enough storage"; a cancel is "Cancelled"', () {
    final full = FileSystemException(
      'write',
      'out.pdf',
      const OSError('No space left on device', 28),
    );
    expect(DokuloError.from(full).situation, DkErrorSituation.notEnoughStorage);
    expect(
      DokuloError.from(const JobCancelled()).situation,
      DkErrorSituation.cancelled,
    );
  });

  test('the catalogue copy, EN and DE, exactly (UI spec §26.3)', () {
    final cases = <DokuloError, (String, String)>{
      const DokuloError(DkErrorSituation.locked): (
        'This PDF is locked.',
        'Diese PDF ist gesperrt.',
      ),
      const DokuloError(DkErrorSituation.damaged): (
        "This file can't be opened.",
        'Diese Datei lässt sich nicht öffnen.',
      ),
      const DokuloError(
        DkErrorSituation.notEnoughStorage,
        neededBytes: 120000000,
      ): (
        'Not enough space on this phone (needs about 120 MB).',
        'Nicht genug Speicher auf diesem Handy (etwa 120 MB nötig).',
      ),
      const DokuloError(DkErrorSituation.cancelled): (
        "Cancelled. Your original file wasn't changed.",
        'Abgebrochen. Deine Originaldatei wurde nicht verändert.',
      ),
      const DokuloError(DkErrorSituation.unexpected, page: 13): (
        'Something went wrong on page 14. (code DK-0190)',
        'Auf Seite 14 ist etwas schiefgegangen. (Code DK-0190)',
      ),
    };
    for (final MapEntry(key: error, value: (english, german))
        in cases.entries) {
      expect(error.title(en), english);
      expect(error.title(de), german);
    }
  });

  test('one recovery action each; none after a cancel; three after an '
      'unexpected failure on a page', () {
    for (final s in DkErrorSituation.values) {
      final actions = DokuloError(s, page: 2).actions;
      switch (s) {
        case DkErrorSituation.cancelled:
          expect(actions, isEmpty);
        case DkErrorSituation.unexpected:
          expect(actions, [
            DkRecovery.tryAgain,
            DkRecovery.skipPage,
            DkRecovery.sendReport,
          ]);
        default:
          expect(actions, hasLength(1), reason: '$s');
      }
    }
    expect(
      const DokuloError(DkErrorSituation.unexpected).actions,
      isNot(contains(DkRecovery.skipPage)),
      reason: 'no page, nothing to skip',
    );
    expect(DkRecovery.enterPassword.label(en), 'Enter password');
    expect(DkRecovery.tryRepair.label(de), 'Reparieren versuchen');
  });

  testWidgets('reproducible with the fixtures: the locked and the damaged '
      'PDF (DK-0610, DK-0611)', (tester) async {
    await tester.runAsync(() async {
      final locked = await thrownBy(
        () => PdfEngine.inspect(fixture('encrypted-aes256.pdf')),
      );
      expect(locked.situation, DkErrorSituation.locked);
      expect(locked.actions, [DkRecovery.enterPassword]);
      final empty = File(
        '${Directory.systemTemp.createTempSync('dk_err_').path}/junk.pdf',
      )..writeAsStringSync('not a pdf at all');
      final damaged = await thrownBy(() => PdfEngine.inspect(empty.path));
      expect(damaged.situation, DkErrorSituation.damaged);
      expect(damaged.actions, [DkRecovery.tryRepair]);
    });
  });

  test('the preflight errors read as the catalogue: the space needed, and '
      'too large with Split it first (DK-0020, DK-0613)', () {
    final storage = DokuloError.from(
      const DocError(DocErrorKind.notEnoughStorage, bytes: 119500000),
    );
    expect(
      storage.title(en),
      'Not enough space on this phone (needs about 120 MB).',
    );
    final large = DokuloError.from(const DocError(DocErrorKind.tooLarge));
    expect(
      large.title(en),
      'This file is too large to process at once on this phone.',
    );
    expect(
      large.title(de),
      'Diese Datei ist zu groß, um sie auf diesem Handy auf einmal zu '
      'verarbeiten.',
    );
    expect(large.actions, [DkRecovery.splitFirst]);
    expect(DkRecovery.splitFirst.label(en), 'Split it first');
  });
}
