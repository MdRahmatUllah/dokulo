import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'haptics.g.dart';

/// Haptics (UI spec §9; DK-0039): one method per moment the spec names, so a
/// widget can't pick a feedback the spec doesn't. There is deliberately no
/// method for errors: the message is enough. No sounds either (the camera
/// shutter follows the OS).
class DkHaptics {
  DkHaptics({
    Future<void> Function()? selection,
    Future<void> Function()? light,
    Future<void> Function()? medium,
  }) : _selection = selection ?? HapticFeedback.selectionClick,
       _light = light ?? HapticFeedback.lightImpact,
       _medium = medium ?? HapticFeedback.mediumImpact;

  final Future<void> Function() _selection, _light, _medium;

  /// A chip, tile or segment is selected.
  Future<void> selected() => _selection();

  /// The scanner captures a page.
  Future<void> captured() => _light();

  /// A dragged item lands (Organize, tile reorder, page drop).
  Future<void> dropped() => _light();

  /// A file is saved successfully.
  Future<void> saved() => _medium();
}

/// The app's haptics; tests override it with a recording fake.
@Riverpod(keepAlive: true)
DkHaptics haptics(Ref ref) => DkHaptics();
