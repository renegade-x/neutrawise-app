import 'package:flutter/material.dart';

class AppColors {
  // Neutrals (Dark Mode)
  static const Color backgroundDark = Color(0xFF000000);
  static const Color surfaceDark = Color(
    0xFF161616,
  ); // Off-black for cards/surfaces
  static const Color surfaceDarkSecondary = Color(0xFF222222);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFA0A0A0); // Light Grey

  // Neutrals (Light Mode)
  static const Color backgroundLight = Color(
    0xFFF8F9FA,
  ); // Off-white clean background
  static const Color surfaceLight = Color(
    0xFFFFFFFF,
  ); // Pure white cards/surfaces
  static const Color surfaceLightSecondary = Color(
    0xFFF1F3F5,
  ); // Light grey elevated cards
  static const Color textPrimaryLight = Color(0xFF121212); // Near black
  static const Color textSecondaryLight = Color(0xFF6C757D); // Dark slate grey

  // Accents (Kept same in both Light and Dark modes)
  static const Color primaryBlue = Color(0xFF4696D2);
  static const Color primaryGreen = Color(0xFF82C92C);

  // Gradients (Kept same in both Light and Dark modes)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBlue, primaryGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Dynamic Theme Helpers
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      isDark(context) ? backgroundDark : backgroundLight;

  static Color surface(BuildContext context) =>
      isDark(context) ? surfaceDark : surfaceLight;

  static Color surfaceSecondary(BuildContext context) =>
      isDark(context) ? surfaceDarkSecondary : surfaceLightSecondary;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? textPrimaryDark : textPrimaryLight;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? textSecondaryDark : textSecondaryLight;

  static Color border(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.1);

  static Color divider(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.1);

  // Dynamic Theme Asset Helpers
  static String logo(BuildContext context) =>
      isDark(context) ? 'assets/images/logo_d.png' : 'assets/images/logo_l.png';

  static String icon(BuildContext context) =>
      isDark(context) ? 'assets/images/icon_d.jpg' : 'assets/images/icon_l.png';
}
