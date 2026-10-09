import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'wicchu_icons.dart';

abstract final class WicchuColors {
  static const primary = Color(0xFF176B5B);
  static const primaryContainer = Color(0xFFD8F0E8);
  static const backgroundLight = Color(0xFFFAFAF8);
  static const headerLight = Color(0xFFEAF5F1);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const secondarySurfaceLight = Color(0xFFF1F2EE);
  static const textLight = Color(0xFF1B1C1B);
  static const secondaryTextLight = Color(0xFF656A67);
  static const borderLight = Color(0xFFE1E4E1);

  static const primaryDark = Color(0xFF79D6BB);
  static const primaryContainerDark = Color(0xFF164E43);
  static const backgroundDark = Color(0xFF101714);
  static const navigationDark = Color(0xFF1C2923);
  static const elevatedSurfaceDark = Color(0xFF26372F);
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
      secondaryContainer: isDark
          ? WicchuColors.primaryContainerDark
          : WicchuColors.primaryContainer,
      onSecondaryContainer: isDark
          ? WicchuColors.textDark
          : const Color(0xFF00201A),
      error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A),
      onError: isDark ? const Color(0xFF690005) : Colors.white,
      surface: isDark ? WicchuColors.surfaceDark : WicchuColors.surfaceLight,
      surfaceContainer: isDark
          ? WicchuColors.navigationDark
          : WicchuColors.secondarySurfaceLight,
      surfaceContainerLow: isDark
          ? WicchuColors.elevatedSurfaceDark
          : WicchuColors.surfaceLight,
      onSurface: isDark ? WicchuColors.textDark : WicchuColors.textLight,
    );
    final border = isDark ? WicchuColors.borderDark : WicchuColors.borderLight;

    return ThemeData(
      fontFamily: 'Plus Jakarta Sans',
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(WicchuIcons.arrowLeft),
        closeButtonIconBuilder: (_) => const Icon(WicchuIcons.x),
      ),
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? WicchuColors.backgroundDark
          : WicchuColors.backgroundLight,
      dividerColor: border,
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return scheme.surface;
            return states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: .38);
            }
            return states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurface;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: border)),
        ),
      ),
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
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurface,
          ),
        ),
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
