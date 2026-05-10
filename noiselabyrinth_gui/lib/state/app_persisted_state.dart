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
  const AppPersistedState({required this.selectedFooter, required this.welcomeDismissed});

  final int selectedFooter;
  final bool welcomeDismissed;

  AppPersistedState copyWith({int? selectedFooter, bool? welcomeDismissed}) {
    return AppPersistedState(
      selectedFooter: selectedFooter ?? this.selectedFooter,
      welcomeDismissed: welcomeDismissed ?? this.welcomeDismissed,
    );
  }
}

class AppPersistedNotifier extends StateNotifier<AppPersistedState> {
  AppPersistedNotifier(this._prefs)
    : super(
        AppPersistedState(
          selectedFooter: _prefs.getInt(_footerKey) ?? 0,
          welcomeDismissed: _prefs.getBool(_welcomeKey) ?? false,
        ),
      );

  static const _footerKey = 'selected_footer';
  static const _welcomeKey = 'welcome_dismissed';

  final SharedPreferences _prefs;

  Future<void> setFooter(int index) async {
    state = state.copyWith(selectedFooter: index, welcomeDismissed: true);
    await _prefs.setInt(_footerKey, state.selectedFooter);
    await _prefs.setBool(_welcomeKey, true);
  }

  Future<void> resetWelcome() async {
    state = state.copyWith(welcomeDismissed: false);
    await _prefs.setBool(_welcomeKey, false);
  }
}
