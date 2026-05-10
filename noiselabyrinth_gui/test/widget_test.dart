import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:noiselabyrinth_gui/main.dart';

void main() {
  testWidgets('shows welcome on first run and switches to main panel', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AppPersistedState.load(prefs);
    await tester.pumpWidget(MyApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);

    await tester.tap(find.byTooltip('Quick start'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsNothing);
    expect(find.text('Quick start - Widget 1'), findsOneWidget);
  });
}
