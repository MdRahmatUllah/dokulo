import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/tools/tool_catalogue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../routes/routes_test.dart' show pumpAt;

/// Screen-reader labels (DK-0637): every screen the router reaches, as it
/// first opens, has a label on every control a screen reader can tap
/// (Flutter's labeledTapTargetGuideline). The components have their own
/// checks (catalogue_test); this one catches a screen that puts an
/// unlabelled control together. TalkBack and VoiceOver passes are recorded
/// in docs/qa/accessibility.md.
void main() {
  final screens = <String, String>{
    'O1 onboarding': Routes.welcome,
    'H1 Home': Routes.home,
    'T1 Tools': Routes.tools,
    'F1 Files': Routes.files,
    'F1 search': Routes.filesSearch,
    'Recently deleted': Routes.trash,
    'F2 locked folder': Routes.lockedFolder,
    'M1 Me': Routes.me,
    'M2 AI models': Routes.models,
    'Signatures': Routes.signatures,
    'M3 Security': Routes.settings('security'),
    'M3 Files & storage': Routes.settings('files'),
    'S1 scanner': Routes.scan,
    for (final tool in ToolCatalogue.all)
      if (tool.id != 'scan') 'T2 ${tool.id}': Routes.tool(tool.id),
  };

  for (final MapEntry(key: name, value: location) in screens.entries) {
    testWidgets('$name: every tappable control has a label', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      await pumpAt(tester, location);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  }
}
