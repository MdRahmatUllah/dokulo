import 'dart:io';

import 'package:app_pdf/l10n/app_language.dart';
import 'package:app_pdf/providers/job_notices.dart';
import 'package:app_pdf/providers/language_providers.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// DK-0587: the notice a job gets when it ends in the background (§25.1).
void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('dk_notice_'));
  tearDown(() => dir.deleteSync(recursive: true));

  JobNotice notice(
    AppLanguage language, {
    JobOutput? output,
    bool failed = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        appLanguageSettingProvider.overrideWithBuild((ref, _) => language),
      ],
    );
    addTearDown(container.dispose);
    final p = Provider(
      (ref) => jobEndedNotice(
        ref,
        jobId: 7,
        toolId: 'compress',
        output: output,
        failed: failed,
      ),
    );
    return container.read(p);
  }

  test('finished: the tool, the file and its size; links to the job', () {
    final file = File('${dir.path}/Mietvertrag.pdf')
      ..writeAsBytesSync(List.filled(2048, 0));
    final n = notice(AppLanguage.english, output: OneFile(file.path));
    expect(n.title, 'Compress PDF finished');
    expect(n.body, matches(RegExp(r'^Mietvertrag\.pdf · 2\s?KB$')));
    expect(n.channel, 'jobs');
    expect(n.channelName, 'Jobs');
    expect(n.toMap()['link'], 'dokulo://open/job/7');
    expect(n.toMap()['id'], 7);
  });

  test('German, several files', () {
    final n = notice(AppLanguage.deutsch, output: const ManyFiles(['a', 'b']));
    expect(n.title, 'PDF verkleinern abgeschlossen');
    expect(n.body, '2 Dateien');
    expect(n.channelName, 'Aufträge');
  });

  test('failed: "Couldn\'t finish", tap for details', () {
    final n = notice(AppLanguage.english, failed: true);
    expect(n.title, "Couldn't finish Compress PDF");
    expect(n.body, 'Tap to see what happened');
  });
}
