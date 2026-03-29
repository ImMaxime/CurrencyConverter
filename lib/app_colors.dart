import 'package:flutter/material.dart';

/// Fixed accent & gradient colors shared across themes.
abstract final class AppColors {
  // ── Accent colors ────────────────────────────────────────────────────
  static const purple = Color(0xFF7C4DFF);
  static const blue = Color(0xFF448AFF);
  static const pink = Color(0xFFE040FB);

  // ── Background gradient (dark) ─────────────────────────────────────
  static const darkGradient = [
    Color(0xFF0D0221),
    Color(0xFF1A0533),
    Color(0xFF2D1B69),
    Color(0xFF1B1464),
    Color(0xFF0F0C29),
  ];

  // ── Background gradient (light) ─────────────────────────────────────
  static const lightGradient = [
    Color(0xFFF5F0FF),
    Color(0xFFE8DEFF),
    Color(0xFFDDD0F5),
    Color(0xFFE0D5F8),
    Color(0xFFF0ECFF),
  ];

  // ── Skeleton shimmer ─────────────────────────────────────────────────
  static const skeletonAlphaMin = 10;
  static const skeletonAlphaMax = 30;
}

/// Brightness-adaptive palette used throughout the UI.
///
/// Dark mode uses white overlays on dark backgrounds.
/// Light mode uses dark overlays on light backgrounds.
/// Access via `AppPalette.of(context)`.
class AppPalette {
  const AppPalette._({
    required this.gradientColors,
    required this.textPrimary,
    required this.textHigh,
    required this.textMedium,
    required this.textMuted,
    required this.textHint,
    required this.iconPrimary,
    required this.iconDim,
    required this.glassFill,
    required this.glassBorder,
    required this.divider,
    required this.highlight,
    required this.refreshFg,
    required this.refreshBg,
    required this.shadowColor,
    required this.dropdownColor,
    required this.orbAlpha,
  });

  // ── Dark palette ─────────────────────────────────────────────────────
  static const dark = AppPalette._(
    gradientColors: AppColors.darkGradient,
    textPrimary: Color(0xFFFFFFFF), // white
    textHigh: Color(0xCCFFFFFF), // 80%
    textMedium: Color(0xB3FFFFFF), // 70%
    textMuted: Color(0x80FFFFFF), // 50% – section labels
    textHint: Color(0x26FFFFFF), // 15%
    iconPrimary: Color(0xCCFFFFFF), // 80%
    iconDim: Color(0x4DFFFFFF), // 30%
    glassFill: Color(0x0DFFFFFF), // 5%
    glassBorder: Color(0x1AFFFFFF), // 10%
    divider: Color(0x14FFFFFF), // 8%
    highlight: Color(0x33FFFFFF), // 20%
    refreshFg: Color(0xE6FFFFFF), // 90%
    refreshBg: Color(0x14FFFFFF), // 8%
    shadowColor: Color(0x1A000000), // 10%
    dropdownColor: Color(0xFF1A1235),
    orbAlpha: 1.0,
  );

  // ── Light palette ────────────────────────────────────────────────────
  static const light = AppPalette._(
    gradientColors: AppColors.lightGradient,
    textPrimary: Color(0xFF453B65), // near-black
    textHigh: Color(0xCC1C1B1F), // 80%
    textMedium: Color(0xB31C1B1F), // 70%
    textMuted: Color(0x801C1B1F), // 50%
    textHint: Color(0x261C1B1F), // 15%
    iconPrimary: Color(0xCC1C1B1F), // 80%
    iconDim: Color(0x4D1C1B1F), // 30%
    glassFill: Color(0xD9FFFFFF), // 85% white – airy frosted glass
    glassBorder: Color(0x40FFFFFF), // 25% white – soft edge
    divider: Color(0x141C1B1F), // 8% dark
    highlight: Color(0xBFFFFFFF), // 75% white
    refreshFg: Color(0xE61C1B1F), // 90%
    refreshBg: Color(0x80FFFFFF), // 50% white
    shadowColor: Color(0x1A000000), // 10%
    dropdownColor: Color(0xFFF5F0FF),
    orbAlpha: 0.5,
  );

  final List<Color> gradientColors;
  final Color textPrimary;
  final Color textHigh;
  final Color textMedium;
  final Color textMuted;
  final Color textHint;
  final Color iconPrimary;
  final Color iconDim;
  final Color glassFill;
  final Color glassBorder;
  final Color divider;
  final Color highlight;
  final Color refreshFg;
  final Color refreshBg;
  final Color shadowColor;
  final Color dropdownColor;
  final double orbAlpha;

  /// Returns the appropriate palette for the current [BuildContext] brightness.
  static AppPalette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
  }
}
