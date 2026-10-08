import 'package:flutter/material.dart';

import '../components/dk_dropdown.dart';
import '../theme/dk_tokens.dart';

const _languages = [('auto', 'Auto'), ('de', 'German'), ('en', 'English')];

/// DkDropdown: a choice, with an error, disabled.
class DkDropdownGallery extends StatelessWidget {
  const DkDropdownGallery({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: context.tokens.space.l,
    children: [
      DkDropdown<String>(
        label: 'Language',
        options: _languages,
        value: 'auto',
        onChanged: (_) {},
      ),
      DkDropdown<String>(
        label: 'Language',
        options: _languages,
        value: 'de',
        onChanged: (_) {},
        error: 'Download German first.',
      ),
      const DkDropdown<String>(
        label: 'Language',
        options: _languages,
        value: 'en',
        onChanged: null,
      ),
    ],
  );
}
