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

class _DkAppLockState extends ConsumerState<DkAppLock> {
  late final AppLifecycleListener _lifecycle;
  DateTime? _hiddenAt;
  var _locked = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _hiddenAt = widget._now();
        // "Immediately": locked before anything shows again.
        final s = ref.read(securitySettingsProvider);
        if (s.appLock && s.lockAfter == 0) _lock();
      },
      onShow: () {
        final s = ref.read(securitySettingsProvider);
        final hidden = _hiddenAt;
        _hiddenAt = null;
        if (s.appLock &&
            hidden != null &&
            widget._now().difference(hidden).inSeconds >= s.lockAfter) {
          _lock();
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _lock() {
    if (!mounted || _locked) return;
    setState(() => _locked = true);
  }

  @override
  Widget build(BuildContext context) {
    // Watched, so the settings (and the prefs under them) are loaded before
    // the app first leaves: a read in onHide alone would see the defaults.
    ref.watch(securitySettingsProvider);
    return Stack(
      children: [
        // Under the lock, the app keeps its state but takes no input.
        ExcludeSemantics(
          excluding: _locked,
          child: IgnorePointer(ignoring: _locked, child: widget.child),
        ),
        if (_locked)
          Positioned.fill(
            child: _LockScreen(
              onUnlocked: () => setState(() => _locked = false),
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
