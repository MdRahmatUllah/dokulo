import 'package:flutter/material.dart';

import '../components/dk_checkbox_row.dart';
import '../components/dk_radio_row.dart';

/// DkRadioRow (with and without a description) and DkCheckboxRow (on with a
/// count, off, disabled).
class DkChoiceRowsGallery extends StatelessWidget {
  const DkChoiceRowsGallery({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RadioGroup<int>(
        groupValue: 0,
        onChanged: (_) {},
        child: const Column(
          children: [
            DkRadioRow(
              value: 0,
              label: 'Both sides',
              description: 'Front and back of each page',
            ),
            DkRadioRow(value: 1, label: 'Front only'),
          ],
        ),
      ),
      DkCheckboxRow(label: 'IBAN', value: true, count: 3, onChanged: (_) {}),
      DkCheckboxRow(label: 'Names', value: false, onChanged: (_) {}),
      const DkCheckboxRow(label: 'Emails', value: true, onChanged: null),
    ],
  );
}
