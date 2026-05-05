import 'package:flutter_test/flutter_test.dart';
import 'package:echo_journal/app.dart';

void main() {
  testWidgets('App starts smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EchoApp());
    expect(find.text('Echo'), findsOneWidget);
  });
}
