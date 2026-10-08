import 'package:flutter/material.dart';

import '../components/dk_icon.dart';
import '../components/dk_icon_button.dart';
import '../components/dk_text_action.dart';
import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';

/// A form over the keyboard (UI spec §12.7; DK-0227): while the keyboard is
/// open, [DkFormAccessoryBar] sits on top of it, under [child]. Put it in a
/// Scaffold body (which the keyboard shrinks); sheets and DkActionBar ride
/// the keyboard by themselves.
class DkFormAccessory extends StatefulWidget {
  const DkFormAccessory({super.key, required this.child, this.onDone});

  final Widget child;

  /// Done; by default it closes the keyboard.
  final VoidCallback? onDone;

  @override
  State<DkFormAccessory> createState() => _DkFormAccessoryState();
}

// The Scaffold takes the keyboard's inset out of its body's MediaQuery (it
// shrinks the body instead), so the window's own insets say whether the
// keyboard is open, and a metrics change says when that changes.
class _DkFormAccessoryState extends State<DkFormAccessory>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => setState(() {});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(child: widget.child),
      if (View.of(context).viewInsets.bottom > 0)
        DkFormAccessoryBar(onDone: widget.onDone),
    ],
  );
}

/// The bar over the keyboard in a form (UI spec §12.7, V2 form filling): 48
/// tall (the export's 44 can't hold 48 dp targets) on `color.surfaceSunken`
/// with a top hairline; Previous field (an arrow) and Next field on the
/// left, Done (bold) on the right. They move the focus without taking it,
/// so the keyboard stays open.
class DkFormAccessoryBar extends StatelessWidget {
  const DkFormAccessoryBar({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final scope = FocusScope.of(context);
    // Tab and the arrows skip the bar: it's for touch, next to the keyboard.
    return ExcludeFocus(
      child: Container(
        height: 49, // 48 dp targets and the hairline
        padding: EdgeInsets.symmetric(horizontal: t.space.s),
        decoration: BoxDecoration(
          color: t.color.surfaceSunken,
          border: Border(top: BorderSide(color: t.color.outline)),
        ),
        child: Row(
          children: [
            DkIconButton(
              icon: DkIcons.previousField,
              tooltip: l.form_previous_field,
              onPressed: () => _toField(scope, forward: false),
            ),
            // Next field gives way at large text; Done keeps its width.
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: DkTextAction(
                  label: l.form_next_field,
                  onTap: () => _toField(scope, forward: true),
                ),
              ),
            ),
            DkTextAction(
              label: l.common_done,
              bold: true,
              onTap:
                  onDone ?? () => FocusManager.instance.primaryFocus?.unfocus(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Moves the focus to the next (or previous) text field in reading order,
/// past checkboxes, buttons and the × in a field, which would close the
/// keyboard. Stays put at the first or last field.
void _toField(FocusScopeNode scope, {required bool forward}) {
  final current = FocusManager.instance.primaryFocus;
  bool isField(FocusNode n) =>
      n.context?.findAncestorWidgetOfExactType<EditableText>() != null;
  final fields = scope.traversalDescendants.where(isField).toList()
    ..sort((a, b) {
      final dy = a.rect.top.compareTo(b.rect.top);
      return dy != 0 ? dy : a.rect.left.compareTo(b.rect.left);
    });
  final i = current == null ? -1 : fields.indexOf(current);
  if (i < 0) return;
  final j = forward ? i + 1 : i - 1;
  if (j >= 0 && j < fields.length) fields[j].requestFocus();
}
