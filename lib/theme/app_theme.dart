import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'glass_tokens.dart';

class AppTheme {
  static const List<String> _fontFallback = [
    'Noto Sans Bengali',
    'Nirmala UI',
    'sans-serif',
  ];

  static TextTheme _buildTextTheme(TextTheme base, {required bool isDark}) {
    final g = isDark ? GlassTokens.dark : GlassTokens.light;
    final primaryColor = g.textPrimary;
    final secondaryColor = g.textSecondary;

    TextStyle s(double size, FontWeight weight, Color color,
        {double? letterSpacing}) {
      return TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        fontFamilyFallback: _fontFallback,
      );
    }

    return GoogleFonts.plusJakartaSansTextTheme(base).copyWith(
      displayLarge: s(32, FontWeight.w800, primaryColor, letterSpacing: -0.5),
      displayMedium: s(28, FontWeight.w700, primaryColor, letterSpacing: -0.3),
      headlineLarge: s(24, FontWeight.w700, primaryColor),
      headlineMedium: s(20, FontWeight.w600, primaryColor),
      titleLarge: s(18, FontWeight.w600, primaryColor),
      titleMedium: s(16, FontWeight.w500, primaryColor),
      titleSmall: s(14, FontWeight.w600, primaryColor),
      bodyLarge: s(16, FontWeight.w400, primaryColor),
      bodyMedium: s(14, FontWeight.w400, secondaryColor),
      bodySmall: s(12, FontWeight.w400, secondaryColor),
      labelLarge: s(14, FontWeight.w600, primaryColor),
      labelMedium: s(12, FontWeight.w500, secondaryColor),
      labelSmall: s(11, FontWeight.w500, secondaryColor),
    );
  }

  static ThemeData lightTheme = (() {
    const g = GlassTokens.light;
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: g.bg,
      primaryColor: g.primary,
      colorScheme: ColorScheme.light(
        primary: g.primary,
        secondary: AppColors.deepForest,
        tertiary: AppColors.accentMintLight,
        surface: g.surface,
        onPrimary: g.onPrimary,
        onSecondary: Colors.white,
        onSurface: g.textPrimary,
      ),
    );
    final textTheme = _buildTextTheme(base.textTheme, isDark: false);

    return base.copyWith(
      textTheme: textTheme,
      extensions: const [GlassTokens.light],
      cardTheme: CardThemeData(
        color: g.glassFill,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: g.glassBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      dividerTheme: DividerThemeData(
        color: g.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: g.glassFillElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: g.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: g.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: g.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: g.primary,
          foregroundColor: g.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: g.primary,
          foregroundColor: g.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            color: g.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: g.glassFill,
          foregroundColor: g.textPrimary,
          side: BorderSide(color: g.glassBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: g.primary,
        foregroundColor: g.onPrimary,
        elevation: 4,
        shape: const CircleBorder(),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: g.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: g.glassBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: g.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: g.surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: g.surface,
        selectedItemColor: g.primary,
        unselectedItemColor: g.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      iconTheme: IconThemeData(color: g.textPrimary),
      listTileTheme: ListTileThemeData(iconColor: g.textPrimary),
    );
  })();

  static ThemeData darkTheme = (() {
    const g = GlassTokens.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: g.bg,
      primaryColor: g.primary,
      colorScheme: ColorScheme.dark(
        primary: g.primary,
        secondary: AppColors.secondaryGreenDark,
        tertiary: AppColors.accentMintLight,
        surface: g.surface,
        onPrimary: g.onPrimary,
        onSecondary: g.textPrimary,
        onSurface: g.textPrimary,
      ),
    );
    final textTheme = _buildTextTheme(base.textTheme, isDark: true);

    return base.copyWith(
      textTheme: textTheme,
      extensions: const [GlassTokens.dark],
      cardTheme: CardThemeData(
        color: g.glassFill,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: g.glassBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      dividerTheme: DividerThemeData(
        color: g.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: g.glassFillElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: g.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: g.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: g.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: g.primary,
          foregroundColor: g.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: g.primary,
          foregroundColor: g.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            color: g.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: g.glassFill,
          foregroundColor: g.textPrimary,
          side: BorderSide(color: g.glassBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: g.primary,
        foregroundColor: g.onPrimary,
        elevation: 4,
        shape: const CircleBorder(),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: g.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: g.glassBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: g.surfaceSubtle,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: g.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: g.surface,
        selectedItemColor: g.primary,
        unselectedItemColor: g.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      iconTheme: IconThemeData(color: g.textPrimary),
      listTileTheme: ListTileThemeData(iconColor: g.textPrimary),
    );
  })();
}
