import 'package:flutter/material.dart';

import '../components/dk_text_field.dart';
import '../theme/dk_tokens.dart';

const _name = 'File name';
const _typed = 'Mietvertrag 2026';
const _help = 'Without .pdf';
const _wrong = 'A name can’t contain “/”.';
const _pw = 'Password';

/// DkTextField and DkPasswordField: empty, with text, helper, error and
/// disabled; the strength meter weak and strong.
class DkTextFieldGallery extends StatefulWidget {
  const DkTextFieldGallery({super.key});

  @override
  State<DkTextFieldGallery> createState() => _DkTextFieldGalleryState();
}

class _DkTextFieldGalleryState extends State<DkTextFieldGallery> {
  final _texts = [
    for (final s in [_typed, 'A/B', _typed, 'abc', 'Wolke-Tisch-42-Bahn'])
      TextEditingController(text: s),
  ];

  @override
  void dispose() {
    for (final t in _texts) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: t.space.l,
      children: [
        const DkTextField(label: _name, hint: _typed),
        DkTextField(label: _name, controller: _texts[0], helper: _help),
        DkTextField(label: _name, controller: _texts[1], error: _wrong),
        DkTextField(label: _name, controller: _texts[2], enabled: false),
        DkPasswordField(label: _pw, controller: _texts[3], showStrength: true),
        DkPasswordField(label: _pw, controller: _texts[4], showStrength: true),
      ],
    );
  }
}
