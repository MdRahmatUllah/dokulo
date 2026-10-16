import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reduce Motion (DK-0643; UI spec §28): every file that animates also
/// asks for Reduce Motion, through `context.motion(...)` (durations go to
/// zero), `context.reduceMotion`, `disableAnimations`, or a controller that
/// keeps its own behaviour (`AnimationBehavior.preserve`). A new animation
/// that forgets fails here, not on a user with vestibular disorders.
void main() {
  test('every animating file in lib/ respects Reduce Motion', () {
    final animates = RegExp(
      // AnimatedBuilder only listens to an animation made elsewhere.
      r'AnimationController\(|Animated(?!Builder\()[A-Z]\w*\(|'
      r'TweenAnimationBuilder|'
      r'\.animateTo\(|\.animateToPage\(',
    );
    final respects = RegExp(
      r'context\.motion\(|reduceMotion|disableAnimations|'
      r'AnimationBehavior\.preserve',
    );
    final missing = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            !f.path.endsWith('.g.dart') &&
            !f.path.contains('l10n'))
          if (f.readAsStringSync() case final s
              when animates.hasMatch(s) && !respects.hasMatch(s))
            f.path,
    ];
    expect(missing, isEmpty);
  });
}
