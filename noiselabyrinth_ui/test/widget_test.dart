import 'package:flutter_test/flutter_test.dart';
import 'package:noiselabyrinth_ui/app.dart';

void main() {
  testWidgets('App shell renders main navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const NoiseLabyrinthApp());
    await tester.pumpAndSettle();

    expect(find.text('Noise Labyrinth'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Player'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
