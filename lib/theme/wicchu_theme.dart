import 'package:flutter/material.dart';

abstract final class WicchuColors {
  static const primary = Color(0xFF176B5B);
  static const primaryContainer = Color(0xFFD8F0E8);
  static const backgroundLight = Color(0xFFFAFAF7);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const secondarySurfaceLight = Color(0xFFF1F2EE);
  static const textLight = Color(0xFF1B1C1B);
  static const secondaryTextLight = Color(0xFF656A67);
  static const borderLight = Color(0xFFE1E4E1);

  static const primaryDark = Color(0xFF78D5BD);
  static const primaryContainerDark = Color(0xFF164E43);
  static const backgroundDark = Color(0xFF101412);
  static const surfaceDark = Color(0xFF191E1B);
  static const secondarySurfaceDark = Color(0xFF222824);
  static const textDark = Color(0xFFE8EDE9);
  static const secondaryTextDark = Color(0xFFAEB7B1);
  static const borderDark = Color(0xFF343B37);
}

abstract final class WicchuTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? WicchuColors.primaryDark : WicchuColors.primary,
      onPrimary: isDark ? const Color(0xFF00382D) : Colors.white,
      primaryContainer: isDark
          ? WicchuColors.primaryContainerDark
          : WicchuColors.primaryContainer,
      onPrimaryContainer: isDark
          ? WicchuColors.textDark
          : const Color(0xFF00201A),
      secondary: isDark
          ? WicchuColors.secondaryTextDark
          : WicchuColors.secondaryTextLight,
      onSecondary: isDark ? WicchuColors.backgroundDark : Colors.white,
      error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A),
      onError: isDark ? const Color(0xFF690005) : Colors.white,
      surface: isDark ? WicchuColors.surfaceDark : WicchuColors.surfaceLight,
      onSurface: isDark ? WicchuColors.textDark : WicchuColors.textLight,
    );
    final border = isDark ? WicchuColors.borderDark : WicchuColors.borderLight;

    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? WicchuColors.backgroundDark
          : WicchuColors.backgroundLight,
      dividerColor: border,
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        height: 68,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? WicchuColors.secondarySurfaceDark
            : WicchuColors.secondarySurfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      useMaterial3: true,
    );
  }
}

Color categoryColor(String category, BuildContext context) =>
    switch (category) {
      'News' => const Color(0xFF3973B7),
      'Marketplace' => const Color(0xFFCC6D24),
      'Jobs' => const Color(0xFF7755A6),
      'Events' => const Color(0xFFB64B78),
      'Politics' => const Color(0xFF64717D),
      'Local Businesses' => const Color(0xFFB07A16),
      'Lost & Found' => const Color(0xFFB44747),
      _ => Theme.of(context).colorScheme.primary,
    };
