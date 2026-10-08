import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'dk_tappable.dart';

/// A text field (DK-0120; UI spec §11.4, §6.5): [label] above in
/// `type.labelM`, a 48 dp `color.surfaceSunken` box with a 1 dp
/// `color.outlineStrong` border (2 dp `color.primary` focused), text in
/// `type.bodyL`, [helper] or [error] 4 dp below in `type.caption`. An error
/// draws the border 2 dp `color.danger` with the `error` icon and the message.
/// A clear button (×) shows while there is text. Screen readers hear the
/// label and the error with the field.
class DkTextField extends StatefulWidget {
  const DkTextField({
    super.key,
    this.label,
    this.controller,
    this.hint,
    this.helper,
    this.error,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.obscureText = false,
    this.clearable = true,
    this.style,
    this.leading,
    this.trailing,
    this.height = 48,
    this.below,
  });

  final String? label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;

  /// Shown instead of [helper], with the danger border.
  final String? error;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool obscureText;

  /// Show the × while there is text.
  final bool clearable;

  /// Instead of `type.bodyL` (DkRangeField uses `type.mono`).
  final TextStyle? style;

  /// Inside the box, before and after the text (after the ×).
  final Widget? leading, trailing;

  /// The box: 48, or 40 for DkSearchField.
  final double height;

  /// Under the helper (DkPasswordField's strength meter).
  final Widget? below;

  @override
  State<DkTextField> createState() => _DkTextFieldState();
}

class _DkTextFieldState extends State<DkTextField> {
  TextEditingController? _own;
  TextEditingController get _text =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _text.addListener(_changed);
  }

  @override
  void didUpdateWidget(DkTextField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _own)?.removeListener(_changed);
      _text.addListener(_changed);
    }
    // A new error is said at once (after Save, say), not only when the
    // field next gets focus.
    final error = widget.error;
    if (error != null && error != old.error) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        error,
        Directionality.of(context),
      );
    }
  }

  @override
  void dispose() {
    _text.removeListener(_changed);
    _own?.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  void _clear() {
    _text.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final error = widget.error;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(t.radius.s),
      borderSide: BorderSide(color: color, width: width),
    );
    final text = widget.style ?? t.text.bodyL;
    final lineHeight = (text.fontSize ?? 16) * (text.height ?? 1.5);
    final showClear =
        widget.clearable && widget.enabled && _text.text.isNotEmpty;
    final trailing = [
      if (showClear)
        DkFieldButton(
          icon: DkIcons.close,
          label: l.common_clear,
          onTap: _clear,
        ),
      ?widget.trailing,
    ];

    final field = TextField(
      controller: _text,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: text.copyWith(color: c.textPrimary),
      cursorColor: c.primary,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: c.surfaceSunken,
        hintText: widget.hint,
        hintStyle: text.copyWith(color: c.textDisabled),
        contentPadding: EdgeInsets.symmetric(
          horizontal: t.space.m,
          vertical: ((widget.height - lineHeight) / 2).clamp(0, 24),
        ),
        enabledBorder: error == null
            ? border(c.outlineStrong, 1)
            : border(c.danger, 2),
        focusedBorder: border(error == null ? c.primary : c.danger, 2),
        disabledBorder: border(c.outline, 1),
        prefixIcon: widget.leading,
        prefixIconConstraints: const BoxConstraints(),
        suffixIcon: trailing.isEmpty
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: trailing),
        suffixIconConstraints: const BoxConstraints(),
      ),
    );

    final note = error ?? widget.helper;
    return Opacity(
      opacity: widget.enabled ? 1 : t.state.disabledOpacity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null) ...[
            ExcludeSemantics(
              child: Text(
                widget.label!,
                style: t.text.labelM.copyWith(color: c.textSecondary),
              ),
            ),
            SizedBox(height: t.space.xs),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.height),
            // The field says its label and error itself; the buttons in
            // it stay their own nodes.
            child: Semantics(
              label: widget.label == null && error == null
                  ? null
                  : [?widget.label, ?error].join('\n'),
              child: field,
            ),
          ),
          if (note != null) ...[
            SizedBox(height: t.space.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (error != null) ...[
                  DkIcon(DkIcons.error, size: DkIconSize.s, color: c.danger),
                  SizedBox(width: t.space.xs),
                ],
                Expanded(
                  // The error is part of the field's label; a helper is
                  // read on its own.
                  child: ExcludeSemantics(
                    excluding: error != null,
                    child: Text(
                      note,
                      style: t.text.caption.copyWith(
                        color: error == null ? c.textSecondary : c.danger,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          ?widget.below,
        ],
      ),
    );
  }
}

/// A small icon button inside a field (×, reveal, pick pages, filter):
/// 20 dp icon, 48 × the field's [height] to touch, with its label for screen
/// readers.
class DkFieldButton extends StatelessWidget {
  const DkFieldButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.height = 48,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// The field's height (48; 40 in a search bar).
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    onTap: onTap,
    child: DkTappable(
      onTap: onTap,
      radius: context.tokens.radius.s,
      builder: (context, pressed) => SizedBox(
        width: 48,
        height: height,
        child: Center(
          child: DkIcon(
            icon,
            size: DkIconSize.m,
            color: context.tokens.color.iconSecondary,
          ),
        ),
      ),
    ),
  );
}

/// How strong a password is: 1–4 filled segments, "Weak / OK / Strong".
enum DkPasswordStrength {
  weak(1),
  fair(2),
  good(3),
  strong(4);

  const DkPasswordStrength(this.segments);
  final int segments;

  /// A simple measure: length (8, 12) and character kinds (lower, upper,
  /// digits, others; 2, 3). Null for an empty password.
  // ponytail: length and variety only; zxcvbn-style dictionary checks if
  // users pick "Passwort1!" a lot.
  static DkPasswordStrength? of(String password) {
    if (password.isEmpty) return null;
    final kinds = [
      RegExp('[a-z]'),
      RegExp('[A-Z]'),
      RegExp('[0-9]'),
      RegExp('[^a-zA-Z0-9]'),
    ].where((k) => k.hasMatch(password)).length;
    final score =
        (password.length >= 8 ? 1 : 0) +
        (password.length >= 12 ? 1 : 0) +
        (kinds >= 2 ? 1 : 0) +
        (kinds >= 3 ? 1 : 0);
    return DkPasswordStrength.values[(score - 1).clamp(0, 3)];
  }
}

/// A password field (DK-0122): a [DkTextField] with the reveal toggle and,
/// with [showStrength], the strength meter: 4 segments, 4 dp tall, and
/// "Weak" (`color.danger`), "OK" (`color.warning`), "Strong"
/// (`color.success`).
class DkPasswordField extends StatefulWidget {
  const DkPasswordField({
    super.key,
    this.label,
    this.controller,
    this.error,
    this.helper,
    this.onChanged,
    this.onSubmitted,
    this.showStrength = false,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.textInputAction,
  });

  final String? label;
  final TextEditingController? controller;
  final String? error;
  final String? helper;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool showStrength;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputAction? textInputAction;

  @override
  State<DkPasswordField> createState() => _DkPasswordFieldState();
}

class _DkPasswordFieldState extends State<DkPasswordField> {
  var _shown = false;
  TextEditingController? _own;
  TextEditingController get _text =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final strength = widget.showStrength
        ? DkPasswordStrength.of(_text.text)
        : null;
    final (Color tone, String word) = switch (strength) {
      DkPasswordStrength.weak => (c.danger, l.field_password_weak),
      DkPasswordStrength.fair ||
      DkPasswordStrength.good => (c.warning, l.field_password_ok),
      _ => (c.success, l.field_password_strong),
    };
    return DkTextField(
      label: widget.label,
      controller: _text,
      error: widget.error,
      helper: widget.helper,
      obscureText: !_shown,
      clearable: false,
      enabled: widget.enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      textInputAction: widget.textInputAction,
      keyboardType: TextInputType.visiblePassword,
      onSubmitted: widget.onSubmitted,
      onChanged: (v) {
        if (widget.showStrength) setState(() {});
        widget.onChanged?.call(v);
      },
      trailing: DkFieldButton(
        icon: _shown ? DkIcons.conceal : DkIcons.reveal,
        label: _shown ? l.field_password_hide : l.field_password_show,
        onTap: () => setState(() => _shown = !_shown),
      ),
      below: strength == null
          ? null
          : Padding(
              padding: EdgeInsets.only(top: t.space.s),
              child: Row(
                spacing: t.space.xs,
                children: [
                  for (var i = 0; i < 4; i++)
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i < strength.segments ? tone : c.outline,
                          borderRadius: BorderRadius.circular(t.radius.xs),
                        ),
                      ),
                    ),
                  SizedBox(width: t.space.xs),
                  Text(word, style: t.text.caption.copyWith(color: tone)),
                ],
              ),
            ),
    );
  }
}

/// Page ranges (DK-0124): a [DkTextField] in `type.mono` with the example
/// placeholder "1–3, 5, 8–end" and a trailing "Pick pages" button that opens
/// the thumbnail picker ([onPick]). Parsing and the "Page 40 doesn't exist"
/// error are the tool's.
class DkRangeField extends StatelessWidget {
  const DkRangeField({
    super.key,
    this.label,
    this.controller,
    this.error,
    this.helper,
    this.onChanged,
    required this.onPick,
    this.enabled = true,
  });

  final String? label;
  final TextEditingController? controller;
  final String? error;
  final String? helper;
  final ValueChanged<String>? onChanged;
  final VoidCallback onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DkTextField(
      label: label,
      controller: controller,
      error: error,
      helper: helper,
      onChanged: onChanged,
      enabled: enabled,
      hint: l.field_range_hint,
      style: context.tokens.text.mono,
      keyboardType: TextInputType.text,
      trailing: DkFieldButton(
        icon: DkIcons.gridView,
        label: l.field_range_pick,
        onTap: onPick,
      ),
    );
  }
}

/// A search box (DK-0126; UI spec §11.4): a 40 dp `color.surfaceSunken` box
/// (`radius.s`), the `search` icon (20) first, the placeholder in
/// `type.bodyL` ("Search tools"), the clear × while there is text, and an
/// optional [filter] button at the end. The row is 48 tall: the box sits in
/// its middle and the buttons take the full 48 to touch (the 4 dp above and
/// below the box count), as DkSegmented's segments do.
class DkSearchField extends StatefulWidget {
  const DkSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.filter,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;

  /// A trailing filter button (a [DkFieldButton]).
  final Widget? filter;

  @override
  State<DkSearchField> createState() => _DkSearchFieldState();
}

class _DkSearchFieldState extends State<DkSearchField> {
  TextEditingController? _own;
  TextEditingController get _text =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _text.addListener(_changed);
  }

  @override
  void didUpdateWidget(DkSearchField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _own)?.removeListener(_changed);
      _text.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _text.removeListener(_changed);
    _own?.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  void _clear() {
    _text.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final style = t.text.bodyL.copyWith(color: c.textPrimary);
    final line =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) * style.height!;
    return SizedBox(
      height: 48,
      child: Stack(
        children: [
          Positioned.fill(
            top: 4,
            bottom: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surfaceSunken,
                borderRadius: BorderRadius.circular(t.radius.s),
              ),
            ),
          ),
          Row(
            children: [
              Padding(
                padding: EdgeInsets.only(left: t.space.m, right: t.space.s),
                child: DkIcon(
                  DkIcons.search,
                  size: DkIconSize.m,
                  color: c.iconSecondary,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _text,
                  focusNode: widget.focusNode,
                  autofocus: widget.autofocus,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  textInputAction: TextInputAction.search,
                  style: style,
                  cursorColor: c.primary,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: style.copyWith(color: c.textSecondary),
                    // The text is a 48 dp target too: the row's full height.
                    contentPadding: EdgeInsets.symmetric(
                      vertical: ((48 - line) / 2).clamp(0, 24),
                    ),
                  ),
                ),
              ),
              if (_text.text.isNotEmpty)
                DkFieldButton(
                  icon: DkIcons.close,
                  label: l.common_clear,
                  onTap: _clear,
                ),
              ?widget.filter,
              if (_text.text.isEmpty && widget.filter == null)
                SizedBox(width: t.space.m),
            ],
          ),
        ],
      ),
    );
  }
}
