import 'package:flutter/material.dart';
import 'package:noiselabyrinth_gui/state/app_persisted_state.dart';
import 'package:noiselabyrinth_gui/state/preset_library_state.dart';
import 'package:noiselabyrinth_gui/widgets/main_shell.dart';

class MyApp extends StatelessWidget {
  const MyApp({
    required this.state,
    required this.presetLibraryState,
    super.key,
  });

  final AppPersistedState state;
  final PresetLibraryState presetLibraryState;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[state, presetLibraryState]),
      builder: (context, _) {
        return MaterialApp(
          title: 'NoiseLabyrinth',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.system,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          home: MainShell(
            state: state,
            presetLibraryState: presetLibraryState,
          ),
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2D5B85), brightness: Brightness.light);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF4F7FB),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF6B7EB8), brightness: Brightness.dark);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF1A2028),
      cardTheme: CardThemeData(
        color: const Color(0xFF252D38),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
