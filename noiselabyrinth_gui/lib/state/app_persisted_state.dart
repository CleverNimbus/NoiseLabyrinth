import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Injected from main.dart via ProviderScope overrides.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final appPersistedProvider = StateNotifierProvider<AppPersistedNotifier, AppPersistedState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AppPersistedNotifier(prefs);
});

class AppPersistedState {
  const AppPersistedState({required this.selectedFooter, required this.welcomeDismissed, required this.zoomFactor});

  final int selectedFooter;
  final bool welcomeDismissed;
  final double zoomFactor;

  AppPersistedState copyWith({int? selectedFooter, bool? welcomeDismissed, double? zoomFactor}) {
    return AppPersistedState(
      selectedFooter: selectedFooter ?? this.selectedFooter,
      welcomeDismissed: welcomeDismissed ?? this.welcomeDismissed,
      zoomFactor: zoomFactor ?? this.zoomFactor,
    );
  }
}

class AppPersistedNotifier extends StateNotifier<AppPersistedState> {
  AppPersistedNotifier(this._prefs)
    : super(
        AppPersistedState(
          selectedFooter: _prefs.getInt(_footerKey) ?? 0,
          welcomeDismissed: _prefs.getBool(_welcomeKey) ?? false,
          zoomFactor: _normalizeZoom(_prefs.getDouble(_zoomKey) ?? _defaultZoom),
        ),
      );

  static const _footerKey = 'selected_footer';
  static const _welcomeKey = 'welcome_dismissed';
  static const _zoomKey = 'app_zoom_factor';

  static const double minZoom = 0.5;
  static const double maxZoom = 2.0;
  static const double zoomStep = 0.1;
  static const double _defaultZoom = 1.0;

  final SharedPreferences _prefs;

  static double _normalizeZoom(double value) {
    final clamped = value.clamp(minZoom, maxZoom);
    return (clamped * 10).round() / 10;
  }

  Future<void> setFooter(int index) async {
    state = state.copyWith(selectedFooter: index, welcomeDismissed: true);
    await _prefs.setInt(_footerKey, state.selectedFooter);
    await _prefs.setBool(_welcomeKey, true);
  }

  Future<void> resetWelcome() async {
    state = state.copyWith(welcomeDismissed: false);
    await _prefs.setBool(_welcomeKey, false);
  }

  Future<void> setZoom(double value) async {
    final normalized = _normalizeZoom(value);
    if (normalized == state.zoomFactor) {
      return;
    }
    state = state.copyWith(zoomFactor: normalized);
    await _prefs.setDouble(_zoomKey, normalized);
  }

  Future<void> zoomIn() => setZoom(state.zoomFactor + zoomStep);

  Future<void> zoomOut() => setZoom(state.zoomFactor - zoomStep);

  Future<void> resetZoom() => setZoom(_defaultZoom);
}
