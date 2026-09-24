import 'package:flutter/material.dart';

class AppColors {
  // ─── Light Theme Colors ───
  static const Color primaryTeal = Color(0xFF1B3A4B);
  static const Color secondaryGreen = Color(0xFF2D5F4F);
  static const Color accentLime = Color(0xFFA8E06C);
  static const Color accentLavender = Color(0xFFC8B6E2);
  static const Color backgroundLight = Color(0xFFE8EAED);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF5F6F8);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnDarkSecondary = Color(0xFFB0BEC5);

  // ─── Dark Theme Colors ───
  static const Color primaryTealDark = Color(0xFF0F2633);
  static const Color secondaryGreenDark = Color(0xFF1A3D32);
  static const Color backgroundDark = Color(0xFF0A1A24);
  static const Color cardDark = Color(0xFF152D3A);
  static const Color surfaceDark = Color(0xFF1A3545);
  static const Color textPrimaryDark = Color(0xFFE8EAED);
  static const Color textSecondaryDark = Color(0xFF8899A6);

  // ─── Semantic Colors ───
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF42A5F5);

  // ─── Priority Colors ───
  static const Color priorityHigh = Color(0xFFEF5350);
  static const Color priorityMedium = Color(0xFFFFA726);
  static const Color priorityLow = Color(0xFF66BB6A);

  // ─── Category Default Colors ───
  static const List<Color> categoryColors = [
    Color(0xFF1B3A4B),
    Color(0xFF2D5F4F),
    Color(0xFFA8E06C),
    Color(0xFFC8B6E2),
    Color(0xFF42A5F5),
    Color(0xFFFFA726),
    Color(0xFFEF5350),
    Color(0xFF26A69A),
    Color(0xFFAB47BC),
    Color(0xFF5C6BC0),
  ];

  // ─── Gradient ───
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryTeal, secondaryGreen],
  );

  static const LinearGradient headerGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryTealDark, secondaryGreenDark],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentLime, Color(0xFF7BC74D)],
  );
}
