import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPersistedState extends ChangeNotifier {
  AppPersistedState({required this.prefs, required this.selectedFooter, required this.welcomeDismissed});

  static const _footerKey = 'selected_footer';
  static const _welcomeKey = 'welcome_dismissed';

  final SharedPreferences prefs;
  int selectedFooter;
  bool welcomeDismissed;

  static AppPersistedState load(SharedPreferences prefs) {
    return AppPersistedState(
      prefs: prefs,
      selectedFooter: prefs.getInt(_footerKey) ?? 0,
      welcomeDismissed: prefs.getBool(_welcomeKey) ?? false,
    );
  }

  Future<void> setFooter(int index) async {
    selectedFooter = index;
    welcomeDismissed = true;
    await prefs.setInt(_footerKey, selectedFooter);
    await prefs.setBool(_welcomeKey, true);
    notifyListeners();
  }

  Future<void> resetWelcome() async {
    welcomeDismissed = false;
    await prefs.setBool(_welcomeKey, false);
    notifyListeners();
  }
}
