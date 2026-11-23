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
        // Markdown base: link color + block styles (tinted code/table/
        // quote, hairline borders per DESIGN.md §4), built once here.
        // Headings are NOT set here — every markdown surface wraps
        // itself in markdown.dart's whisper heading theme (shared
        // ladder 16/15/14, w500, tier-damped; user sync call
        // 2026-11-21).
        GptMarkdownThemeData(
          brightness: brightness,
          linkColor: scheme.primary,
          styleSheet: GptMarkdownStyleSheet(
            blockSpacing: 8,
            blockQuote: BlockQuoteStyle(
              barColor: scheme.outlineVariant,
              // Soft tinted card behind the quote (Doubao parity — a bare
              // side bar reads as an error stripe on a chat surface).
              backgroundColor: scheme.secondaryContainer.withValues(alpha: 0.45),
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
            // Inline code as a quiet whisper, not a badge (Doubao parity):
            // slightly smaller than the body, tinted fill, no border.
            // borderWidth: 0 must be explicit — the fork's resolve()
            // defaults to a 1px outline when the field is unset (copyWith
            // can't express "unset" later).
            inlineCode: InlineCodeStyle(
              fontSizeFactor: 0.9,
              color: scheme.onSurfaceVariant,
              backgroundColor: scheme.secondaryContainer.withValues(alpha: 0.6),
              borderWidth: 0,
              borderRadius: const Radius.circular(4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            ),
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
        // and title on a phone. One title RULE app-wide (user sync call
        // 2026-11-19: 大标题同正文尺寸只加字重) — each surface's title
        // is that surface's body size + w600: AppBar pages use body 15
        // (the 17px step read as a second app bar inside the page); the
        // chat header uses transcript 13.5 (chat_page).
        titleSpacing: 8,
        leadingWidth: 48,
        titleTextStyle: TextStyle(
          fontSize: AppType.body,
          fontWeight: FontWeight.w600,
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
      // Every popup menu in the app shares one chrome: card-family
      // surface/radius (the M3 default container tint doesn't match the
      // cool-cyan dark surfaces) and the ladder's row-copy rung
      // (labelMedium 13 w500) — M3's labelLarge default read a step
      // above the 13.5 rows the menus act on (user call 2026-11-23).
      popupMenuTheme: PopupMenuThemeData(
        color: colors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(AppRadius.card)),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: AppType.secondary, fontWeight: FontWeight.w500, color: colors.cardForeground),
        ),
      ),
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

  /// zh long-form leading (DESIGN.md: 中文正文行高 1.7 是铁律); en stays
  /// 1.5. Shared by markdownConfig and [readerBody] so markdown bodies and
  /// their handwritten neighbors can never drift apart (ticket M4-10).
  static double zhBodyHeight(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'zh' ? 1.7 : 1.5;

  /// Handwritten-prose rung sitting next to a markdown body: reader
  /// chrome (article insights, diary detail, card/wiki surfaces), the
  /// chat user bubble — anywhere plain Text renders what a neighboring
  /// transcriptMarkdown would. Derived from the SAME bodyMedium base
  /// markdownConfig starts from, plus the transcript size and zh
  /// leading — the two "identical" styles can't drift apart (user call
  /// 2026-11-21: readers join the chat size). The dark-mode body
  /// step-down (375, see markdownConfig) applies here too — the two
  /// sides of the contract move together.
  static TextStyle? readerBody(BuildContext context, {Color? color}) =>
      Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: AppType.transcript,
          height: zhBodyHeight(context),
          color: color,
          fontWeight: Theme.of(context).brightness == Brightness.dark
              ? const FontWeight(375)
              : null);

  /// Chat chrome metadata line (chat header's agent·model, drawer agent
  /// header's model) — the chatMeta step in the outline color. Single
  /// source so the two chrome surfaces can't drift apart.
  static TextStyle chatMetaStyle(ColorScheme colors) =>
      TextStyle(fontSize: AppType.chatMeta, color: colors.outline);

  /// List-row subtitle (the gray descriptor under the title): one notch
  /// under bodySmall (user feedback 2026-11-21) — the timestamp family
  /// stays the smallest metadata role.
  static TextStyle listSubtitleStyle(ColorScheme colors) =>
      TextStyle(fontSize: AppType.caption, color: colors.onSurfaceVariant);
}
