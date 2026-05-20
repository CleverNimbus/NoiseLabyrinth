import 'package:flutter_test/flutter_test.dart';
import 'package:noiselabyrinth_gui/state/app_persisted_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persists zoom and clamps to valid range', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = AppPersistedNotifier(prefs);

    expect(notifier.state.zoomFactor, 1.0);

    await notifier.setZoom(1.25);
    expect(notifier.state.zoomFactor, 1.3);
    expect(prefs.getDouble('app_zoom_factor'), 1.3);

    await notifier.setZoom(3.0);
    expect(notifier.state.zoomFactor, AppPersistedNotifier.maxZoom);

    await notifier.setZoom(0.2);
    expect(notifier.state.zoomFactor, AppPersistedNotifier.minZoom);
  });

  test('zoom controls update zoom by step and can reset', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = AppPersistedNotifier(prefs);

    await notifier.zoomIn();
    expect(notifier.state.zoomFactor, 1.1);

    await notifier.zoomOut();
    expect(notifier.state.zoomFactor, 1.0);

    await notifier.setZoom(1.7);
    await notifier.resetZoom();
    expect(notifier.state.zoomFactor, 1.0);
  });
}
