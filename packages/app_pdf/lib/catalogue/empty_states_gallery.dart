import 'package:flutter/material.dart';

import '../patterns/dk_empty_states.dart';
import '../theme/dk_tokens.dart';

/// The empty states of UI spec §26.1 (DK-0601…DK-0608), one after another.
class EmptyStatesGallery extends StatelessWidget {
  const EmptyStatesGallery({super.key});

  @override
  Widget build(BuildContext context) {
    void none() {}
    return Column(
      spacing: context.tokens.space.xl,
      children: [
        DkEmptyStates.homeRecents(context, onScan: none),
        DkEmptyStates.filesRoot(context, onScan: none, onOpenFile: none),
        DkEmptyStates.folder(context, onMove: none),
        DkEmptyStates.search(context, query: 'Kaution'),
        DkEmptyStates.trash(context),
        DkEmptyStates.signatures(context, onAdd: none),
        DkEmptyStates.workflows(context, onNew: none, onTemplate: none),
        DkEmptyStates.photoFinder(context, onClose: none),
      ],
    );
  }
}
