import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_elf/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PantryPalApp());
    expect(find.byType(PantryPalApp), findsOneWidget);
  });
}
