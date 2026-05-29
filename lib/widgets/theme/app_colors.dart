import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors (Eco-friendly greens but premium)
  static const Color primary = Color(0xFF0D9488); // Teal
  static const Color primaryDark = Color(0xFF0F766E);
  static const Color primaryLight = Color(0xFF99F6E4);

  // Secondary/Accent Colors
  static const Color accent = Color(0xFFFDE047); // Yellow for XP/Gamification
  static const Color accentLight = Color(0xFFFEF08A);

  // Neutrals (Light Mode)
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);

  // Neutrals (Dark Mode)
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
