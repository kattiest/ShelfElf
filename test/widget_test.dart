import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_elf/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ShelfElfApp());
    expect(find.byType(ShelfElfApp), findsOneWidget);
  });
}
