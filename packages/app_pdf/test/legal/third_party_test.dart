import 'dart:io';

import 'package:app_pdf/legal/third_party.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// The register's rows (DK-0672) in the sections that become the licence
/// screen's hand-kept part: their first cells, for what ships.
List<String> registerRows() {
  final register = File('../../docs/compliance/licence-register.md')
      .readAsStringSync();
  final rows = <String>[];
  for (final section in [
    '## Native libraries',
    '## Models',
    '## Colour profiles',
    '## Fonts',
  ]) {
    final start = register.indexOf(section);
    final end = register.indexOf('\n## ', start + 1);
    for (final line
        in register
            .substring(start, end < 0 ? register.length : end)
            .split('\n')) {
      final cells = line.split('|').map((c) => c.trim()).toList();
      if (cells.length < 5 || cells[1].isEmpty) continue;
      if (cells[1] == 'Component' || cells[1].startsWith('---')) continue;
      if (cells[1] == 'Model' || cells[1] == 'Profile') continue;
      if (cells[1] == 'Font') continue;
      // The OS's own frameworks, and what comes later, don't ship now.
      if (cells[3] == 'OS' || cells[1].contains('later')) continue;
      rows.add(cells[1].replaceAll('`', ''));
    }
  }
  return rows;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every shipping row of the register has its licence entry', () {
    final rows = registerRows();
    expect(rows, isNotEmpty);
    for (final row in rows) {
      expect(
        thirdParty.any(
          (t) => row.contains(t.name.split(RegExp(r'[ ,]')).first),
        ),
        isTrue,
        reason: 'no ThirdParty entry for "$row" (lib/legal/third_party.dart)',
      );
    }
  });

  test('the obligations: the IJG credit, PP-OCR converted not modified, '
      'the fonts\' licence texts', () async {
    LicenseRegistry.addLicense(
      () => Stream.value(const LicenseEntryWithLineBreaks(['pdfrx'], 'MIT …')),
    );
    final all = await licences();
    String text(String name) =>
        all.firstWhere((l) => l.name == name).texts.join('\n');
    expect(text('libjpeg-turbo'), contains('Independent JPEG Group'));
    expect(
      text('PP-OCRv5 (detection, Latin and multilingual recognition, angle)'),
      contains('not modified'),
    );
    expect(text('Caveat'), contains('SIL OPEN FONT LICENSE'));
    expect(text('Dancing Script'), contains('SIL OPEN FONT LICENSE'));
    expect(text('Homemade Apple'), contains('Apache License'));
    expect(text('pdfrx'), 'MIT …');
    final names = all.map((l) => l.name.toLowerCase()).toList();
    expect(names, orderedEquals([...names]..sort()));
  });
}
