import 'package:flutter_test/flutter_test.dart';
import 'package:poschair_check/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const PostureCheckerApp(initialDark: true));
    await tester.pump();
  });
}
