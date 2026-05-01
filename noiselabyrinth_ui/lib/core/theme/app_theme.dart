import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const _background = Color(0xFF090B0F);
  static const _surface = Color(0xFF121722);
  static const _surfaceElevated = Color(0xFF192131);
  static const _accent = Color(0xFF5FA8F8);
  static const _accentMuted = Color(0xFF7CC1FF);
  static const _danger = Color(0xFFCF7A4A);

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final colorScheme = const ColorScheme.dark(
      brightness: Brightness.dark,
      surface: _surface,
      primary: _accent,
      secondary: _accentMuted,
      error: _danger,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _background,
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      cardTheme: const CardThemeData(
        color: _surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0xFF243146), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _surface,
        selectedItemColor: _accentMuted,
        unselectedItemColor: Color(0xFF7F8AA3),
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: _surfaceElevated,
        side: const BorderSide(color: Color(0xFF2A3750)),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: _accent,
        inactiveTrackColor: const Color(0xFF2C3650),
        thumbColor: _accentMuted,
        overlayColor: _accent.withValues(alpha: 0.15),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: _surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFF324260)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFF324260)),
        ),
      ),
    );
  }
}
