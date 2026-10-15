import 'package:flutter/material.dart';

import '../components/dk_confirm_dialog.dart';
import '../components/dk_text_field.dart';
import '../components/motion/dk_transition_motion.dart';
import '../theme/dk_tokens.dart';

/// Asks for a name (UI spec §16.4: New folder, Rename): DkConfirmDialog with
/// a focused DkTextField, the action disabled while it's empty. [validate]
/// returns an error to show under the field ("A folder with this name
/// already exists."), or null to accept. The trimmed name, or null on
/// Cancel.
Future<String?> showDkTextDialog(
  BuildContext context, {
  required String title,
  required String action,
  String? hint,
  String initial = '',
  String? suffix,
  TextSelection? selection,
  Future<String?> Function(String name)? validate,
}) => Navigator.of(context, rootNavigator: true).push<String>(
  DkDialogRoute.of(
    context,
    builder: (context) => _TextDialog(
      title: title,
      action: action,
      hint: hint,
      initial: initial,
      suffix: suffix,
      selection: selection,
      validate: validate,
    ),
  ),
);

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.action,
    required this.hint,
    required this.initial,
    required this.suffix,
    required this.selection,
    required this.validate,
  });

  final String title, action, initial;
  final String? hint;

  /// Shown after the field and kept out of the name (a file's ".pdf").
  final String? suffix;
  final TextSelection? selection;
  final Future<String?> Function(String name)? validate;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection =
        widget.selection ??
        TextSelection(baseOffset: 0, extentOffset: widget.initial.length);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final error = await widget.validate?.call(name);
    if (!mounted) return;
    if (error != null) return setState(() => _error = error);
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => DkConfirmDialog(
    title: widget.title,
    action: widget.action,
    onCancel: () => Navigator.pop(context),
    onAction: _controller.text.trim().isEmpty ? null : _submit,
    content: DkTextField(
      controller: _controller,
      hint: widget.hint,
      error: _error,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onChanged: (_) => setState(() => _error = null),
      onSubmitted: (_) => _submit(),
      trailing: widget.suffix == null
          ? null
          : Padding(
              padding: EdgeInsetsDirectional.only(end: context.tokens.space.m),
              child: Text(
                widget.suffix!,
                style: context.tokens.text.bodyL.copyWith(
                  color: context.tokens.color.textSecondary,
                ),
              ),
            ),
    ),
  );
}
