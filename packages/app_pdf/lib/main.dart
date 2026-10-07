import 'package:doc_tools/doc_tools.dart';
import 'package:flutter/material.dart';

void main() => runApp(const DokuloApp());

/// The app root. The shell, routes and theme arrive with DK-0004 and DK-0024.
class DokuloApp extends StatelessWidget {
  const DokuloApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    title: 'Dokulo',
    home: Scaffold(body: Center(child: Text('Dokulo · layer $docToolsLayer'))),
  );
}
