import 'package:flutter/material.dart';

class AppColors {
  // Neutrals (Dark Mode - Primary Theme)
  static const Color backgroundDark = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF161616); // Off-black for cards/surfaces for depth
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFF5F5F5); // Light Grey

  // Accents
  static const Color primaryBlue = Color(0xFF4696D2); 
  static const Color primaryGreen = Color(0xFF82C92C);

  // Gradients
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
}
