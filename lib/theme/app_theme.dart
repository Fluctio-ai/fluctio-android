import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

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
      extensions: [
        // Markdown reading surface: compact heading ladder (the web
        // contract's tokens — fromTheme display-scale made h1 tower
        // over a 15px body), the surge-cyan link color, and the block
        // styles (tinted code/table/quote, hairline borders per
        // DESIGN.md §4). Built once here instead of per markdown call.
        GptMarkdownThemeData(
          brightness: brightness,
          h1: TextStyle(fontSize: AppType.headline, fontWeight: FontWeight.w600, height: 1.4, color: scheme.onSurface),
          h2: TextStyle(fontSize: AppType.docH2, fontWeight: FontWeight.w600, height: 1.4, color: scheme.onSurface),
          h3: TextStyle(fontSize: AppType.docH3, fontWeight: FontWeight.w600, height: 1.45, color: scheme.onSurface),
          h4: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w600, color: scheme.onSurface),
          h5: TextStyle(fontSize: AppType.docH5, fontWeight: FontWeight.w600, color: scheme.onSurface),
          h6: TextStyle(fontSize: AppType.secondary, fontWeight: FontWeight.w500, color: scheme.onSurface),
          linkColor: scheme.primary,
          styleSheet: GptMarkdownStyleSheet(
            blockSpacing: 8,
            blockQuote: BlockQuoteStyle(
              barColor: scheme.outlineVariant,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            ),
            codeBlock: CodeBlockStyle(
              backgroundColor: scheme.secondaryContainer,
              borderColor: scheme.outlineVariant,
              borderRadius: AppRadius.control,
              padding: const EdgeInsets.all(12),
              borderWidth: 0.5,
            ),
            table: TableStyle(borderColor: scheme.outlineVariant),
            hr: HrStyle(color: scheme.outlineVariant),
            inlineCode: const InlineCodeStyle(fontFamily: 'monospace'),
          ),
        ),
      ],
      // The app's only type scale (DESIGN.md §3), mapped onto Material
      // roles so screens share it through textTheme instead of hand-set
      // sizes. Built from scratch — not copied from Typography.material3 —
      // so no role carries the M3 letter-spacing defaults (zh bans
      // tracking). Roles sharing a step split by weight, not size.
      textTheme: _textTheme(),
      scaffoldBackgroundColor: colors.background,
      appBarTheme: AppBarTheme(
        // Tight top-bar rhythm — the M3 defaults (leadingWidth 56,
        // titleSpacing 16) leave wide gutters between menu/back icon
        // and title on a phone. One title spec app-wide (design
        // decision 1): the 17px title step. The M3 default (titleLarge,
        // 22px) towers over a 15px body column; 22px stays reserved for
        // display/headline surfaces (setup, empty states).
        titleSpacing: 8,
        leadingWidth: 48,
        titleTextStyle: TextStyle(
          fontSize: AppType.title,
          fontWeight: FontWeight.w500,
          height: 1.45,
          color: colors.cardForeground,
        ),
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
