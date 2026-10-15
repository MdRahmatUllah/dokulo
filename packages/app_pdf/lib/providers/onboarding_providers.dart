import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_providers.g.dart';

/// Whether the intro (O1–O3, DK-0238) has been seen, so it shows once: a
/// marker file in app support. If the flag can't be read, the intro is
/// skipped rather than shown on every launch. Me → Replay intro opens
/// `/welcome` again without clearing it.
@Riverpod(keepAlive: true)
class OnboardingDone extends _$OnboardingDone {
  @override
  Future<bool> build() async {
    try {
      return await (await _flag()).exists();
    } on Exception {
      return true;
    }
  }

  Future<File> _flag() async => File(
    '${(await getApplicationSupportDirectory()).path}'
    '${Platform.pathSeparator}onboarding_done',
  );

  /// Skip, a start-with card, or Next on the last page.
  Future<void> complete() async {
    state = const AsyncData(true);
    try {
      await (await _flag()).create(recursive: true);
    } on Exception {
      // ponytail: shown again next launch at worst; nothing else depends on it
    }
  }
}
