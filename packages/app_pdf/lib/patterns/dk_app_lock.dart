import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/dk_icon.dart';
import '../components/dk_logo.dart';
import '../components/dk_pin_pad.dart';
import '../l10n/app_localizations.dart';
import '../providers/locked_providers.dart';
import '../providers/security_providers.dart';
import '../theme/dk_tokens.dart';

/// The global app lock (DK-0290; UI spec §16.4): with App lock on, coming
/// back after Lock after (Immediately / 1 min / 5 min) covers everything
/// with the lock screen: the Dokulo symbol (56), "Dokulo is locked", the PIN
/// pad and the biometric prompt at once. Biometrics failing leaves the PIN.
/// The app root puts it above the router (`DokuloApp.builder`).
class DkAppLock extends ConsumerStatefulWidget {
  const DkAppLock({super.key, required this.child, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Widget child;
  final DateTime Function() _now;

  @override
  ConsumerState<DkAppLock> createState() => _DkAppLockState();
}

enum _Lock { open, covered, locked }

class _DkAppLockState extends ConsumerState<DkAppLock> {
  late final AppLifecycleListener _lifecycle;
  DateTime? _hiddenAt;
  var _lock = _Lock.open;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      // Covered on leaving, so no content shows on the way back before the
      // lock is decided; the PIN pad (and its biometric prompt) only once
      // the app is back.
      onHide: () {
        _hiddenAt = widget._now();
        if (ref.read(securitySettingsProvider).appLock && _lock == _Lock.open) {
          setState(() => _lock = _Lock.covered);
        }
      },
      onShow: _decide,
    );
  }

  Future<void> _decide() async {
    final hidden = _hiddenAt;
    _hiddenAt = null;
    if (_lock != _Lock.covered) return;
    final s = ref.read(securitySettingsProvider);
    final due =
        hidden != null &&
        widget._now().difference(hidden).inSeconds >= s.lockAfter;
    // Without a PIN nothing could open the lock: prefs restored from a
    // backup that the keychain didn't come with.
    final pin = due && await ref.read(lockedVaultProvider).hasPin;
    if (!mounted) return;
    setState(() => _lock = pin ? _Lock.locked : _Lock.open);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watched, so the settings (and the prefs under them) are loaded before
    // the app first leaves: a read in onHide alone would see the defaults.
    ref.watch(securitySettingsProvider);
    final shut = _lock != _Lock.open;
    return Stack(
      children: [
        // Under the lock, the app keeps its state but takes no input.
        ExcludeSemantics(
          excluding: shut,
          child: IgnorePointer(ignoring: shut, child: widget.child),
        ),
        if (_lock == _Lock.covered)
          Positioned.fill(
            child: ColoredBox(
              color: context.tokens.color.background,
              child: const Center(child: DkLogo.symbol(size: 56)),
            ),
          ),
        if (_lock == _Lock.locked)
          Positioned.fill(
            child: _LockScreen(
              onUnlocked: () => setState(() => _lock = _Lock.open),
            ),
          ),
      ],
    );
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen({required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  String? _error;
  var _errors = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
  }

  Future<void> _biometric() async {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final cipher = await ref
        .read(lockedVaultProvider)
        .unlockWithBiometrics(l.app_lock_reason);
    if (cipher != null && mounted) widget.onUnlocked();
  }

  void _fail(String message) => setState(() {
    _error = message;
    _errors++;
  });

  Future<void> _entered(String pin) async {
    final l = AppLocalizations.of(context);
    switch (await ref.read(lockedVaultProvider).unlockWithPin(pin)) {
      case PinUnlocked():
        widget.onUnlocked();
      case PinWrong():
        _fail(l.locked_pin_wrong);
      case PinThrottled(:final wait):
        _fail(l.locked_pin_wait(wait.inSeconds));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final kind = ref.watch(biometricKindProvider).value;
    return Material(
      color: t.color.background,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(t.space.l),
          child: Column(
            children: [
              SizedBox(height: t.space.xl),
              const DkLogo.symbol(size: 56),
              SizedBox(height: t.space.m),
              Semantics(
                header: true,
                child: Text(
                  l.app_lock_title,
                  style: t.text.titleM.copyWith(color: t.color.textPrimary),
                ),
              ),
              SizedBox(height: t.space.l),
              Expanded(
                child: DkPinPad(
                  expand: true,
                  error: _error,
                  errorCount: _errors,
                  onComplete: _entered,
                  onBiometric: kind == null ? null : _biometric,
                  biometricIcon: kind == BiometricKind.faceId
                      ? DkIcons.faceId
                      : DkIcons.fingerprint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
