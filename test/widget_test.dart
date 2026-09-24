import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const MoneyTrackerApp());
    expect(find.text('Money Tracker'), findsOneWidget);
  });
}
