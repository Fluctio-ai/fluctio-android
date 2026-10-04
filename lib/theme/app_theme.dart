import 'package:flutter/material.dart';

import 'tokens.dart';

/// Material themes built from the web token tables (no seed/tonal
/// generation — the palette is fixed by design). Component radii follow
/// the web families: 6px controls, 12px cards/menus/modals.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light, appPaletteLight);

  static ThemeData dark() => _build(Brightness.dark, appPaletteDark);

  static ThemeData _build(Brightness brightness, AppPalette colors) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.primaryForeground,
      primaryContainer: colors.accent,
      onPrimaryContainer: colors.accentForeground,
      secondary: colors.accent,
      onSecondary: colors.accentForeground,
      secondaryContainer: colors.secondary,
      onSecondaryContainer: colors.secondaryForeground,
      tertiary: colors.brand,
      onTertiary: colors.primaryForeground,
      error: colors.destructive,
      onError: colors.primaryForeground,
      surface: colors.card,
      onSurface: colors.cardForeground,
      surfaceContainerHighest: colors.secondary,
      onSurfaceVariant: colors.mutedForeground,
      outline: colors.mutedForeground,
      outlineVariant: colors.border,
      inverseSurface: colors.accentForeground,
      onInverseSurface: colors.accent,
      inversePrimary: colors.primaryForeground,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // The app's only type scale (DESIGN.md §3), mapped onto Material
      // roles so screens share it through textTheme instead of hand-set
      // sizes. Built from scratch — not copied from Typography.material3 —
      // so no role carries the M3 letter-spacing defaults (zh bans
      // tracking). Roles sharing a step split by weight, not size.
      textTheme: _textTheme(),
      scaffoldBackgroundColor: colors.background,
      appBarTheme: const AppBarTheme(
        // Tight top-bar rhythm — the M3 defaults (leadingWidth 56,
        // titleSpacing 16) leave wide gutters between menu/back icon
        // and title on a phone.
        titleSpacing: 8,
        leadingWidth: 48,
      ),
      splashFactory: InkSparkle.splashFactory,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: AppRadius.controlBorder)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: AppRadius.controlBorder)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: AppRadius.controlBorder)),
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder, side: BorderSide(color: colors.border)),
      ),
      dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.secondary,
        border: OutlineInputBorder(borderRadius: AppRadius.controlBorder, borderSide: BorderSide(color: colors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.controlBorder, borderSide: BorderSide(color: colors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.controlBorder, borderSide: BorderSide(color: colors.ring, width: 1.5)),
      ),
      dividerTheme: DividerThemeData(color: colors.border, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.background,
        indicatorColor: colors.accent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: states.contains(WidgetState.selected) ? colors.accentForeground : colors.mutedForeground),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: AppType.caption,
            color: states.contains(WidgetState.selected) ? colors.accentForeground : colors.mutedForeground,
          ),
        ),
      ),
    );
  }

  /// Material roles onto the ladder: display 28 / headline 22 (incl.
  /// titleLarge, the top-bar role) / title 17 / body 15 (incl. titleSmall
  /// and labelLarge at w500) / secondary 13 / caption 12. Heights tuned
  /// for CJK lists; the chat reading column overrides to 1.7 itself.
  static TextTheme _textTheme() {
    const w400 = FontWeight.w400;
    const w500 = FontWeight.w500;
    const w600 = FontWeight.w600;
    return TextTheme(
      displayLarge: TextStyle(fontSize: AppType.display, height: 1.3),
      displayMedium: TextStyle(fontSize: AppType.display, height: 1.3),
      displaySmall: TextStyle(fontSize: AppType.display, height: 1.3),
      headlineLarge: TextStyle(fontSize: AppType.display, height: 1.3),
      headlineMedium: TextStyle(fontSize: AppType.headline, height: 1.35),
      headlineSmall: TextStyle(fontSize: AppType.headline, height: 1.35),
      titleLarge: TextStyle(fontSize: AppType.headline, height: 1.35, fontWeight: w600),
      titleMedium: TextStyle(fontSize: AppType.title, height: 1.45, fontWeight: w500),
      titleSmall: TextStyle(fontSize: AppType.body, height: 1.45, fontWeight: w500),
      bodyLarge: TextStyle(fontSize: AppType.body, height: 1.5, fontWeight: w400),
      bodyMedium: TextStyle(fontSize: AppType.body, height: 1.5, fontWeight: w400),
      bodySmall: TextStyle(fontSize: AppType.secondary, height: 1.45, fontWeight: w400),
      labelLarge: TextStyle(fontSize: AppType.body, height: 1.4, fontWeight: w500),
      labelMedium: TextStyle(fontSize: AppType.secondary, height: 1.4, fontWeight: w500),
      labelSmall: TextStyle(fontSize: AppType.caption, height: 1.4, fontWeight: w500),
    );
  }
}
