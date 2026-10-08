import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// Every enabled button on screen can be pressed with a screen reader: it has
/// a tap action. (A `Semantics(excludeSemantics: true)` over an InkWell drops
/// the InkWell's tap unless the Semantics sets `onTap` itself.) Call it with
/// semantics on (`tester.ensureSemantics()`).
void expectPressableButtons(WidgetTester tester) => expect(
  find.semantics.byPredicate((node) {
    final d = node.getSemanticsData();
    return d.flagsCollection.isButton &&
        d.flagsCollection.isEnabled != Tristate.isFalse &&
        !d.hasAction(SemanticsAction.tap);
  }, describeMatch: (_) => 'buttons a screen reader cannot press'),
  findsNothing,
);
