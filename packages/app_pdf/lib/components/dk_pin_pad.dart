import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';

/// The PIN pad (DK-0148; UI spec §11.4): six 12 dp dots for the digits
/// entered, a 3 × 4 keypad of 72 dp circles in `type.titleL`, the
/// biometric key bottom left ([onBiometric], announced as [biometricLabel]),
/// delete bottom right. A hardware keyboard's digits and backspace work too.
/// Bump [errorCount] after a wrong PIN: the dots shake (with Reduce Motion
/// they don't; the [error] text says it).
class DkPinPad extends StatefulWidget {
  const DkPinPad({
    super.key,
    required this.onComplete,
    this.length = 6,
    this.onBiometric,
    this.biometricIcon = DkIcons.fingerprint,
    this.biometricLabel,
    this.error,
    this.errorCount = 0,
  });

  /// Called with the PIN when all digits are in; the pad then clears.
  final ValueChanged<String> onComplete;
  final int length;
  final VoidCallback? onBiometric;
  final IconData biometricIcon;

  /// "Use Face ID" / "Use fingerprint": the platform's word.
  final String? biometricLabel;

  /// Shown under the dots ("Wrong PIN. 2 tries left.").
  final String? error;

  /// Goes up with each wrong PIN; a change shakes the dots.
  final int errorCount;

  @override
  State<DkPinPad> createState() => _DkPinPadState();
}

class _DkPinPadState extends State<DkPinPad>
    with SingleTickerProviderStateMixin {
  final _focus = FocusNode();
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  var _digits = '';

  @override
  void didUpdateWidget(DkPinPad old) {
    super.didUpdateWidget(old);
    if (widget.errorCount != old.errorCount && !context.reduceMotion) {
      _shake
        ..duration = context.tokens.motion.emphasis
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _type(String d) {
    if (_digits.length >= widget.length) return;
    setState(() => _digits += d);
    if (_digits.length == widget.length) {
      final pin = _digits;
      setState(() => _digits = '');
      widget.onComplete(pin);
    }
  }

  void _delete() {
    if (_digits.isNotEmpty) {
      setState(() => _digits = _digits.substring(0, _digits.length - 1));
    }
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final ch = e.character;
    if (ch != null && RegExp(r'^[0-9]$').hasMatch(ch)) {
      _type(ch);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _delete();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    Widget key({
      required Widget child,
      required String label,
      VoidCallback? onTap,
      bool plain = false,
    }) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 72,
          height: 72,
          margin: EdgeInsets.all(t.space.s),
          decoration: plain
              ? null
              : BoxDecoration(shape: BoxShape.circle, color: c.surfaceSunken),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
    Widget digit(String d) => key(
      label: d,
      onTap: () => _type(d),
      child: Text(d, style: t.text.titleL.copyWith(color: c.textPrimary)),
    );
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _shake,
            builder: (context, child) => Transform.translate(
              // Three swings, fading out.
              offset: Offset(
                12 * math.sin(_shake.value * 6 * math.pi) * (1 - _shake.value),
                0,
              ),
              child: child,
            ),
            child: Semantics(
              label: '${_digits.length} / ${widget.length}',
              liveRegion: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: t.space.m,
                children: [
                  for (var i = 0; i < widget.length; i++)
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _digits.length ? c.primary : null,
                        border: Border.all(
                          color: widget.error != null && _digits.isEmpty
                              ? c.danger
                              : c.outlineStrong,
                          width: 2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: t.space.m),
          SizedBox(
            height: 20,
            child: widget.error == null
                ? null
                : Semantics(
                    liveRegion: true,
                    child: Text(
                      widget.error!,
                      style: t.text.bodyM.copyWith(color: c.danger),
                    ),
                  ),
          ),
          SizedBox(height: t.space.l),
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final d in row) digit(d)],
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onBiometric != null)
                key(
                  plain: true,
                  label: widget.biometricLabel ?? '',
                  onTap: widget.onBiometric,
                  child: DkIcon(
                    widget.biometricIcon,
                    size: DkIconSize.xxl,
                    color: c.iconPrimary,
                  ),
                )
              else
                const SizedBox(width: 88),
              digit('0'),
              key(
                plain: true,
                label: l.pin_delete_digit,
                onTap: _delete,
                child: DkIcon(
                  DkIcons.backspace,
                  size: DkIconSize.l,
                  color: c.iconPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
