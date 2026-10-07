import 'package:app_pdf/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the app starts', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DokuloApp()));
    expect(find.text('Dokulo · layer 2'), findsOneWidget);
  });
}
