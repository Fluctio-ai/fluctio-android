import 'package:flutter/material.dart';

import 'oklch.dart';

/// Design tokens, transcribed 1:1 from fastclaw `web/src/app/globals.css`
/// (:root light block, .dark dark block). Keep the oklch literals exactly
/// in sync with the CSS when the web theme changes; entries where the CSS
/// already names a hex value keep that hex so both ends stay bit-identical.
///
/// Light theme: pure neutral grayscale with a single surge-cyan accent
/// axis. Dark theme: "deep water" — surfaces carry a faint cool-cyan cast
/// (chroma ≤ 0.012) and primary glows one step brighter.
class AppPalette {
  final Color background, foreground;
  final Color card, cardForeground;
  final Color primary, primaryForeground;
  final Color secondary, secondaryForeground;
  final Color mutedForeground;
  final Color accent, accentForeground;
  final Color brand;
  final Color destructive;
  final Color border, input, ring;
  final Color success, successForeground;
  final Color warning, warningForeground;
  final Color info;
  final Color chart1, chart2, chart3, chart4, chart5;

  const AppPalette({
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.brand,
    required this.destructive,
    required this.border,
    required this.input,
    required this.ring,
    required this.success,
    required this.successForeground,
    required this.warning,
    required this.warningForeground,
    required this.info,
    required this.chart1,
    required this.chart2,
    required this.chart3,
    required this.chart4,
    required this.chart5,
  });
}

/// Light: pure neutral grayscale + surge-cyan axis. Primary fill is
/// cyan-700 (4.95:1 with its white label — AA for fill and text).
final appPaletteLight = AppPalette(
  background: const Color(0xFFFFFFFF), // oklch(1 0 0)
  foreground: const Color(0xFF171717), // oklch(0.145 0 0)
  card: const Color(0xFFFFFFFF),
  cardForeground: const Color(0xFF171717),
  primary: const Color(0xFF0E7490), // surge cyan
  primaryForeground: const Color(0xFFFAFAFA), // oklch(0.985 0 0)
  secondary: const Color(0xFFF5F5F5), // oklch(0.97 0 0)
  secondaryForeground: const Color(0xFF333333), // oklch(0.205 0 0)
  mutedForeground: const Color(0xFF757575), // oklch(0.556 0 0)
  accent: const Color(0xFFECFEFF), // cyan-50 selection/hover base
  accentForeground: const Color(0xFF155E75), // cyan-800, 7.8:1 on accent
  brand: const Color(0xFF0E7490),
  // Rosy red — cyan's complement on the chart ring; deep step keeps AA.
  destructive: oklch(0.52, 0.19, 12),
  border: const Color(0xFFEAEAEA), // oklch(0.922 0 0)
  input: const Color(0xFFEAEAEA),
  ring: const Color(0xFF0E7490), // focus ring = surge cyan
  // Semantic status — light steps sit deep on purpose (small text on /10
  // tints needs ≥4.5:1). Info stays on the cyan axis.
  success: oklch(0.52, 0.14, 168), // teal-green
  successForeground: const Color(0xFFFAFAFA),
  warning: oklch(0.55, 0.12, 68), // gold
  warningForeground: const Color(0xFF333333),
  info: const Color(0xFF155E75), // cyan-800, deep step for text
  // Chart palette — categorical ring around the cyan axis, equal
  // lightness; avoids amber so a series never reads as the warning state.
  chart1: const Color(0xFF0891B2), // cyan-600
  chart2: oklch(0.55, 0.16, 262), // blue
  chart3: oklch(0.55, 0.18, 305), // violet
  chart4: oklch(0.62, 0.20, 350), // rose
  chart5: oklch(0.55, 0.12, 180), // teal
);

/// Dark: "deep water" — cool-cyan cast on surfaces (chroma ≤ 0.012),
/// primary glows one step brighter, primary text stays neutral white.
final appPaletteDark = AppPalette(
  background: oklch(0.145, 0.008, 230),
  foreground: const Color(0xFFEDEDED), // oklch(0.985 0 0)
  card: oklch(0.178, 0.010, 230), // one step up, same cast
  cardForeground: const Color(0xFFEDEDED),
  primary: const Color(0xFF22D3EE), // cyan-400
  primaryForeground: const Color(0xFF083344), // cyan-950, 9:1 on the fill
  secondary: oklch(0.22, 0.012, 230),
  secondaryForeground: const Color(0xFFEDEDED),
  mutedForeground: oklch(0.65, 0.015, 230),
  accent: const Color(0xFF083344), // cyan-950 selection base
  accentForeground: const Color(0xFF67E8F9), // cyan-300
  brand: const Color(0xFF22D3EE),
  destructive: oklch(0.68, 0.17, 12), // lifted for dark
  border: const Color.fromRGBO(255, 255, 255, 0.10), // translucent hairline
  input: const Color.fromRGBO(255, 255, 255, 0.15),
  ring: const Color(0xFF22D3EE),
  success: oklch(0.72, 0.14, 172),
  successForeground: const Color(0xFF171717),
  warning: oklch(0.78, 0.13, 68),
  warningForeground: const Color(0xFF171717),
  info: const Color(0xFF22D3EE),
  chart1: oklch(0.72, 0.13, 220), // cyan
  chart2: oklch(0.72, 0.15, 262), // blue
  chart3: oklch(0.72, 0.16, 305), // violet
  chart4: oklch(0.75, 0.15, 350), // rose
  chart5: oklch(0.72, 0.13, 180), // teal
);

/// The active theme's palette — for semantic status colors (success /
/// warning) the M3 ColorScheme has no slot for.
AppPalette paletteOf(BuildContext context) => Theme.of(context).brightness == Brightness.dark
    ? appPaletteDark
    : appPaletteLight;

/// The app's signature grouped-card surface: tinted secondary container,
/// hairline border, card radius. One owner instead of per-page copies.
BoxDecoration surfaceCardDecoration(ColorScheme scheme) => BoxDecoration(
      color: scheme.secondaryContainer.withValues(alpha: 0.4),
      borderRadius: AppRadius.cardBorder,
      border: Border.all(color: scheme.outlineVariant),
    );

/// Radius families pinned like the web (globals.css @theme): 4px nested,
/// 6px controls, 12px cards/menus/modals, 16px fullscreen.
abstract final class AppRadius {
  static const nested = Radius.circular(4);
  static const control = Radius.circular(6);
  static const card = Radius.circular(12);
  static const fullscreen = Radius.circular(16);

  static final controlBorder = BorderRadius.all(control);
  static final cardBorder = BorderRadius.all(card);
}
