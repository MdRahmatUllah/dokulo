import 'package:flutter/material.dart';

import '../components/dk_detection_group.dart';
import '../theme/dk_tokens.dart';

/// DkDetectionGroup (DK-0220), as on Black out's find sheet: IBAN expanded
/// with two items, Tax ID with one item off (the dash), Email collapsed, and
/// an AI suggestion listed as a count only. Live: tap the checkboxes and the
/// rows. The data is made up.
class DetectionGroupStates extends StatefulWidget {
  const DetectionGroupStates({super.key});

  static const iban = IconData(0xe84f, fontFamily: 'MaterialSymbolsRounded');
  static const badge = IconData(0xea67, fontFamily: 'MaterialSymbolsRounded');
  static const mail = IconData(0xe158, fontFamily: 'MaterialSymbolsRounded');
  static const person = IconData(0xe7fd, fontFamily: 'MaterialSymbolsRounded');

  @override
  State<DetectionGroupStates> createState() => _DetectionGroupStatesState();
}

class _DetectionGroupStatesState extends State<DetectionGroupStates> {
  final groups = <(IconData, String, List<DkDetection>, bool)>[
    (
      DetectionGroupStates.iban,
      'IBAN',
      const [
        DkDetection(
          preview: 'DE00 •••• •••• •••• 0000 00',
          page: 1,
          checked: true,
        ),
        DkDetection(
          preview: 'DE00 •••• •••• •••• 0000 01',
          page: 3,
          checked: true,
        ),
      ],
      true,
    ),
    (
      DetectionGroupStates.badge,
      'Tax ID',
      const [
        DkDetection(preview: '00 ••• ••• 000', page: 1, checked: true),
        DkDetection(preview: '00 ••• ••• 001', page: 2, checked: false),
      ],
      false,
    ),
    (
      DetectionGroupStates.mail,
      'Email',
      const [
        DkDetection(preview: 'm••••@example.com', page: 1, checked: false),
      ],
      false,
    ),
  ];

  void _set(int g, List<DkDetection> items, {bool? expanded}) => setState(
    () => groups[g] = (
      groups[g].$1,
      groups[g].$2,
      items,
      expanded ?? groups[g].$4,
    ),
  );

  List<DkDetection> _all(List<DkDetection> items, bool on) => [
    for (final i in items)
      DkDetection(preview: i.preview, page: i.page, checked: on),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ColoredBox(
      color: t.color.surface,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: t.space.l),
        child: Column(
          children: [
            for (final (g, (icon, name, items, expanded)) in groups.indexed)
              DkDetectionGroup(
                icon: icon,
                name: name,
                items: items,
                expanded: expanded,
                onExpanded: (v) => _set(g, items, expanded: v),
                onCheckedAll: (on) => _set(g, _all(items, on)),
                onChecked: (i, on) => _set(g, [
                  for (final (j, d) in items.indexed)
                    j == i
                        ? DkDetection(
                            preview: d.preview,
                            page: d.page,
                            checked: on,
                          )
                        : d,
                ]),
                onPage: (_) {},
              ),
            // AI suggestions: a count only, no list.
            DkDetectionGroup(
              icon: DetectionGroupStates.person,
              name: 'Names',
              items: const [
                DkDetection(preview: '', page: 1, checked: false),
                DkDetection(preview: '', page: 2, checked: false),
              ],
              onCheckedAll: (_) {},
              onChecked: (_, _) {},
              onPage: (_) {},
            ),
          ],
        ),
      ),
    );
  }
}
