import 'package:app_pdf/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the app starts', (tester) async {
    await tester.pumpWidget(const DokuloApp());
    expect(find.text('Dokulo · layer 2'), findsOneWidget);
  });
}
