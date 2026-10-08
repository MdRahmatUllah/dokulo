import 'package:flutter/material.dart';

import '../components/dk_tool_options_sheet.dart';
import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';

/// DkToolOptionsSheet (DK-0204) on a sheet's surface, for each tool:
/// highlighter (opacity, as in the export), pen, text, shape, eraser. Live:
/// the sliders, stepper and segments change the options. The colour row is
/// a stand-in until DkColorRow (DK-0142) lands.
class ToolOptionsStates extends StatefulWidget {
  const ToolOptionsStates({super.key});

  @override
  State<ToolOptionsStates> createState() => _ToolOptionsStatesState();
}

class _ToolOptionsStatesState extends State<ToolOptionsStates> {
  final _options = {
    for (final k in DkMarkupKind.values)
      k: DkToolOptions(
        color: k == DkMarkupKind.highlighter
            ? const DkMarkup().yellow
            : const DkMarkup().red,
      ),
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      spacing: t.space.l,
      children: [
        for (final kind in DkMarkupKind.values)
          DecoratedBox(
            decoration: t.surfaceAt(
              DkLevel.overlay,
              radius: BorderRadius.vertical(
                top: Radius.circular(t.radius.sheet),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(t.space.l),
              child: DkToolOptionsSheet(
                kind: kind,
                options: _options[kind]!,
                onChanged: (o) => setState(() => _options[kind] = o),
              ),
            ),
          ),
      ],
    );
  }
}
