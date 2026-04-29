// This is a basic Flutter widget test.
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/main.dart';

void main() {
  testWidgets('Jarvis HUD smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const JarvisFuturisticApp());

    // Verify that our HUD title exists.
    expect(find.text('JARVIS SUPREME'), findsOneWidget);
  });
}
