import 'package:flutter/material.dart';

/// Stands in for a screen until its task builds it: shows the screen ID and
/// a long list, so tab state (scroll position) can be tested. DK-0004.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen(this.screenId, {super.key, this.detail = ''});

  final String screenId;
  final String detail;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('$screenId $detail'.trim())),
    body: ListView.builder(
      key: PageStorageKey(screenId),
      itemCount: 50,
      itemBuilder: (context, i) =>
          ListTile(title: Text('$screenId · ${i + 1}')),
    ),
  );
}
