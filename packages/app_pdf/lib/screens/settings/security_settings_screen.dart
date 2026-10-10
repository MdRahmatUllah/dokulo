import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_action_sheet.dart';
import '../../components/dk_menu.dart';
import '../../components/dk_pin_pad.dart';
import '../../components/dk_settings_row.dart';
import '../../components/dk_switch.dart';
import '../../components/dk_toast.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/locked_providers.dart';
import '../../providers/prefs_providers.dart';
import '../../providers/privacy_providers.dart';
import '../../providers/security_providers.dart';
import '../../theme/dk_tokens.dart';

/// M3 · Security (DK-0573; UI spec §23.3): App lock (off) · Unlock with
/// Face ID / fingerprint · Lock after (Immediately / 1 min / 5 min; 1 min) ·
/// Hide previews in app switcher (on) · Change locked folder PIN. Changes
/// apply at once. App lock and the PIN change need the locked folder's PIN:
/// until it is set, their rows say so.
class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecurityState();
}

class _SecurityState extends ConsumerState<SecuritySettingsScreen> {
  bool? _hasPin, _bio;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final vault = ref.read(lockedVaultProvider);
    final hasPin = await vault.hasPin;
    final bio = await vault.biometricsEnabled;
    if (mounted) {
      setState(() {
        _hasPin = hasPin;
        _bio = bio;
      });
    }
  }

  String _after(AppLocalizations l, int seconds) => switch (seconds) {
    0 => l.security_after_now,
    300 => l.security_after_5min,
    _ => l.security_after_1min,
  };

  Future<void> _bioChanged(bool on) async {
    final l = AppLocalizations.of(context);
    final vault = ref.read(lockedVaultProvider);
    if (on) {
      await vault.enableBiometrics(l.locked_bio_reason);
    } else {
      await vault.disableBiometrics();
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final settings = ref.watch(securitySettingsProvider);
    final prefs = ref.read(prefsProvider.notifier);
    final hide = ref.watch(hidePreviewsProvider);
    final kind = ref.watch(biometricKindProvider).value;
    final hasPin = _hasPin ?? false;
    final bioName = switch (kind) {
      BiometricKind.faceId => l.security_bio_face,
      BiometricKind.touchId => l.security_bio_touch,
      _ => l.security_bio_fingerprint,
    };
    return Scaffold(
      backgroundColor: t.color.background,
      appBar: DkTopBar(title: l.tools_category_security),
      body: ListView(
        padding: EdgeInsets.all(t.space.l),
        children: [
          DkSettingsGroup(
            children: [
              DkSettingsRow(
                title: l.security_app_lock,
                description: hasPin
                    ? l.security_app_lock_body(bioName)
                    : l.security_needs_pin,
                trailing: DkSwitch(
                  value: settings.appLock && hasPin,
                  onChanged: hasPin
                      ? (on) => prefs.set('security.appLock', on)
                      : null,
                ),
              ),
              if (kind != null)
                DkSettingsRow(
                  title: l.security_unlock_with(bioName),
                  trailing: DkSwitch(
                    value: _bio ?? false,
                    onChanged: hasPin ? _bioChanged : null,
                  ),
                ),
              Builder(
                builder: (anchor) => DkSettingsRow(
                  title: l.security_lock_after,
                  value: _after(l, settings.lockAfter),
                  onTap: () => showDkMenu(
                    anchor,
                    groups: [
                      [
                        for (final s in SecuritySettings.lockAfterChoices)
                          DkAction(
                            label: _after(l, s),
                            checked: s == settings.lockAfter,
                            onTap: () => prefs.set('security.lockAfter', s),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              DkSettingsRow(
                title: l.security_hide_previews,
                trailing: DkSwitch(
                  value: hide,
                  onChanged: ref.read(hidePreviewsProvider.notifier).set,
                ),
              ),
              DkSettingsRow(
                title: l.security_change_pin,
                description: hasPin ? null : l.security_needs_pin,
                onTap: hasPin
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ChangePinScreen(),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Change the locked folder's PIN (DK-0292): the current PIN (or
/// biometrics), then the new one twice, on the L2/L3 pad. The folder's key
/// stays as it is, so every file stays readable; the old PIN stops working
/// at once.
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinState();
}

enum _Step { current, create, confirm }

class _ChangePinState extends ConsumerState<ChangePinScreen> {
  var _step = _Step.current;
  String? _first, _error;
  var _errors = 0;

  void _fail(String message) => setState(() {
    _error = message;
    _errors++;
  });

  Future<void> _entered(String pin) async {
    final l = AppLocalizations.of(context);
    final vault = ref.read(lockedVaultProvider);
    switch (_step) {
      case _Step.current:
        switch (await vault.unlockWithPin(pin)) {
          case PinUnlocked():
            setState(() {
              _step = _Step.create;
              _error = null;
            });
          case PinWrong():
            _fail(l.locked_pin_wrong);
          case PinThrottled(:final wait):
            _fail(l.locked_pin_wait(wait.inSeconds));
        }
      case _Step.create:
        setState(() {
          _first = pin;
          _step = _Step.confirm;
          _error = null;
        });
      case _Step.confirm:
        if (pin != _first) {
          _first = null;
          _fail(l.locked_pin_mismatch);
          setState(() => _step = _Step.create);
          return;
        }
        await vault.setPin(pin);
        if (!mounted) return;
        Navigator.pop(context);
        showDkToast(context, l.security_pin_changed);
    }
  }

  Future<void> _biometric() async {
    final l = AppLocalizations.of(context);
    final cipher = await ref
        .read(lockedVaultProvider)
        .unlockWithBiometrics(l.locked_bio_reason);
    if (cipher != null && mounted) {
      setState(() {
        _step = _Step.create;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: t.color.background,
      appBar: DkTopBar(title: l.security_change_pin),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(t.space.l),
          child: Column(
            children: [
              Text(
                switch (_step) {
                  _Step.current => l.security_current_pin,
                  _Step.create => l.locked_create_pin,
                  _Step.confirm => l.locked_confirm_pin,
                },
                style: t.text.titleM.copyWith(color: t.color.textPrimary),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: t.space.l),
              Expanded(
                child: DkPinPad(
                  // A fresh pad per step: its dots start empty.
                  key: ValueKey(_step),
                  expand: true,
                  error: _error,
                  errorCount: _errors,
                  onComplete: _entered,
                  onBiometric: _step == _Step.current ? _biometric : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
