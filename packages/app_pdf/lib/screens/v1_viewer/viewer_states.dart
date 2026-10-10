import 'package:flutter/material.dart';

import '../../components/dk_button.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_illustration.dart';
import '../../components/dk_text_field.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dk_layout.dart';
import '../../theme/dk_tokens.dart';

/// V1 Locked PDF (UI spec §17.1; DK-0301, DK-0302): in place of the pages a
/// centred card, at most 360 wide: a 40 lock, "This PDF is locked", the
/// password and Unlock; a wrong one says "That password doesn't open this
/// file." under the field. [onUnlock] answers whether the password opens it.
class ViewerLockedCard extends StatefulWidget {
  const ViewerLockedCard({super.key, required this.onUnlock});

  final Future<bool> Function(String password) onUnlock;

  @override
  State<ViewerLockedCard> createState() => _ViewerLockedCardState();
}

class _ViewerLockedCardState extends State<ViewerLockedCard> {
  final _password = TextEditingController();
  var _wrong = false;
  var _checking = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_password.text.isEmpty || _checking) return;
    setState(() => _checking = true);
    final ok = await widget.onUnlock(_password.text);
    if (mounted) {
      setState(() {
        _checking = false;
        _wrong = !ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(t.space.l),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: DecoratedBox(
            decoration: t.surfaceAt(
              DkLevel.raised,
              radius: BorderRadius.circular(t.radius.l),
            ),
            child: Padding(
              padding: EdgeInsets.all(t.space.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DkIcon(
                    DkIcons.lock,
                    size: DkIconSize.xl,
                    color: t.color.iconPrimary,
                  ),
                  SizedBox(height: t.space.m),
                  Text(
                    l.viewer_locked_title,
                    style: t.text.titleM.copyWith(color: t.color.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: t.space.l),
                  DkPasswordField(
                    label: l.t2_password,
                    controller: _password,
                    error: _wrong ? l.t2_wrong_password : null,
                    onChanged: (_) {
                      if (_wrong) setState(() => _wrong = false);
                    },
                    onSubmitted: (_) => _unlock(),
                  ),
                  SizedBox(height: t.space.m),
                  DkButton(
                    label: l.t2_unlock,
                    expand: true,
                    loading: _checking,
                    onPressed: _checking ? null : _unlock,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// V1 Damaged file (UI spec §17.1; DK-0305): ILL-14, "This file can't be
/// opened", "It may be damaged.", Close and Try Repair.
class ViewerDamaged extends StatelessWidget {
  const ViewerDamaged({
    super.key,
    required this.onClose,
    required this.onRepair,
  });

  final VoidCallback onClose, onRepair;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(t.space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DkIllustration(DkIllustrations.damagedFile),
            SizedBox(height: t.space.xl),
            Text(
              l.error_damaged,
              style: t.text.titleM.copyWith(color: t.color.textPrimary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: t.space.xs),
            Text(
              l.viewer_damaged_body,
              style: t.text.bodyM.copyWith(color: t.color.textSecondary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: t.space.xl),
            Wrap(
              spacing: t.space.s,
              runSpacing: t.space.s,
              alignment: WrapAlignment.center,
              children: [
                DkButton(
                  label: l.common_close,
                  variant: DkButtonVariant.secondary,
                  onPressed: onClose,
                ),
                DkButton(
                  label: l.error_action_try_repair,
                  icon: DkIcons.tool('repair'),
                  onPressed: onRepair,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
