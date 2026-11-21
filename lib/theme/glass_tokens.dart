import 'package:flutter/material.dart';

/// Consistent spacing scale (4/8dp rhythm).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Consistent corner radii tokens matching soft glassmorphic surfaces.
abstract final class AppRadius {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;
}

/// Consistent vector icon size tokens.
abstract final class AppIconSize {
  static const double sm = 18;
  static const double md = 20;
  static const double lg = 24;
}

/// Shared layout bounds for phone, tablet, and desktop.
abstract final class AppLayout {
  static const double maxContentWidth = 720;
  static const double railBreakpoint = 720;
  static const double navClearance = 108;
}

/// Semantic color + glassmorphism tokens tailored to MoneyTracker's palette.
@immutable
class GlassTokens extends ThemeExtension<GlassTokens> {
  const GlassTokens({
    required this.bg,
    required this.bgGradientTop,
    required this.bgGradientBottom,
    required this.orbPrimary,
    required this.orbAccent,
    required this.orbSecondary,
    required this.glassFill,
    required this.glassFillElevated,
    required this.glassBorder,
    required this.glassShadow,
    required this.surface,
    required this.surfaceSubtle,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
    required this.primarySoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.success,
    required this.warning,
    required this.danger,
    required this.navDockFill,
    required this.navDockBorder,
    required this.navIconInactive,
    required this.navIconActiveBg,
    required this.navIconActiveFg,
  });

  final Color bg;
  final Color bgGradientTop;
  final Color bgGradientBottom;
  final Color orbPrimary;
  final Color orbAccent;
  final Color orbSecondary;
  final Color glassFill;
  final Color glassFillElevated;
  final Color glassBorder;
  final Color glassShadow;
  final Color surface;
  final Color surfaceSubtle;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color onAccent;
  final Color primarySoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color success;
  final Color warning;
  final Color danger;
  final Color navDockFill;
  final Color navDockBorder;
  final Color navIconInactive;
  final Color navIconActiveBg;
  final Color navIconActiveFg;

  static const GlassTokens light = GlassTokens(
    bg: Color(0xFFEFF3EF),
    bgGradientTop: Color(0xFFF6F9F5),
    bgGradientBottom: Color(0xFFE5EDE6),
    orbPrimary: Color(0xFF9AC9AF),
    orbAccent: Color(0xFF8BF29C),
    orbSecondary: Color(0xFFC4DFCE),
    glassFill: Color(0xEBFFFFFF),
    glassFillElevated: Color(0xFAFFFFFF),
    glassBorder: Color(0xFFDAE4DC),
    glassShadow: Color(0x1414452F),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFE6EFE8),
    primary: Color(0xFF14452F),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF14452F),
    onAccent: Color(0xFFFFFFFF),
    primarySoft: Color(0x1814452F),
    textPrimary: Color(0xFF0E1D15),
    textSecondary: Color(0xFF5A6D61),
    border: Color(0xFFCEDBD1),
    success: Color(0xFF1B7A43),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    navDockFill: Color(0xFF14452F),
    navDockBorder: Color(0x28FFFFFF),
    navIconInactive: Color(0xC2E5EFE7),
    navIconActiveBg: Color(0xFFF4F8F4),
    navIconActiveFg: Color(0xFF14452F),
  );

  static const GlassTokens dark = GlassTokens(
    bg: Color(0xFF060C09),
    bgGradientTop: Color(0xFF153E29),
    bgGradientBottom: Color(0xFF050907),
    orbPrimary: Color(0xFF1D5E3C),
    orbAccent: Color(0xFF8BF29C),
    orbSecondary: Color(0xFF123322),
    glassFill: Color(0xB80E1B14),
    glassFillElevated: Color(0xDF13241B),
    glassBorder: Color(0x24FFFFFF),
    glassShadow: Color(0x66000000),
    surface: Color(0xFF0E1B14),
    surfaceSubtle: Color(0xFF15291E),
    primary: Color(0xFF8BF29C),
    onPrimary: Color(0xFF06160C),
    accent: Color(0xFF8BF29C),
    onAccent: Color(0xFF06160C),
    primarySoft: Color(0x248BF29C),
    textPrimary: Color(0xFFF2F7F4),
    textSecondary: Color(0xFF8DA696),
    border: Color(0x1FFFFFFF),
    success: Color(0xFF6EF094),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFFF6B6B),
    navDockFill: Color(0xEB0C1711),
    navDockBorder: Color(0x24FFFFFF),
    navIconInactive: Color(0xFF8DA696),
    navIconActiveBg: Color(0xFF1B3325),
    navIconActiveFg: Color(0xFFF2F7F4),
  );

  @override
  GlassTokens copyWith({
    Color? bg,
    Color? bgGradientTop,
    Color? bgGradientBottom,
    Color? orbPrimary,
    Color? orbAccent,
    Color? orbSecondary,
    Color? glassFill,
    Color? glassFillElevated,
    Color? glassBorder,
    Color? glassShadow,
    Color? surface,
    Color? surfaceSubtle,
    Color? primary,
    Color? onPrimary,
    Color? accent,
    Color? onAccent,
    Color? primarySoft,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? success,
    Color? warning,
    Color? danger,
    Color? navDockFill,
    Color? navDockBorder,
    Color? navIconInactive,
    Color? navIconActiveBg,
    Color? navIconActiveFg,
  }) {
    return GlassTokens(
      bg: bg ?? this.bg,
      bgGradientTop: bgGradientTop ?? this.bgGradientTop,
      bgGradientBottom: bgGradientBottom ?? this.bgGradientBottom,
      orbPrimary: orbPrimary ?? this.orbPrimary,
      orbAccent: orbAccent ?? this.orbAccent,
      orbSecondary: orbSecondary ?? this.orbSecondary,
      glassFill: glassFill ?? this.glassFill,
      glassFillElevated: glassFillElevated ?? this.glassFillElevated,
      glassBorder: glassBorder ?? this.glassBorder,
      glassShadow: glassShadow ?? this.glassShadow,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      primarySoft: primarySoft ?? this.primarySoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      navDockFill: navDockFill ?? this.navDockFill,
      navDockBorder: navDockBorder ?? this.navDockBorder,
      navIconInactive: navIconInactive ?? this.navIconInactive,
      navIconActiveBg: navIconActiveBg ?? this.navIconActiveBg,
      navIconActiveFg: navIconActiveFg ?? this.navIconActiveFg,
    );
  }

  @override
  GlassTokens lerp(ThemeExtension<GlassTokens>? other, double t) {
    if (other is! GlassTokens) return this;
    return GlassTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      bgGradientTop: Color.lerp(bgGradientTop, other.bgGradientTop, t)!,
      bgGradientBottom:
          Color.lerp(bgGradientBottom, other.bgGradientBottom, t)!,
      orbPrimary: Color.lerp(orbPrimary, other.orbPrimary, t)!,
      orbAccent: Color.lerp(orbAccent, other.orbAccent, t)!,
      orbSecondary: Color.lerp(orbSecondary, other.orbSecondary, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassFillElevated:
          Color.lerp(glassFillElevated, other.glassFillElevated, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassShadow: Color.lerp(glassShadow, other.glassShadow, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      navDockFill: Color.lerp(navDockFill, other.navDockFill, t)!,
      navDockBorder: Color.lerp(navDockBorder, other.navDockBorder, t)!,
      navIconInactive:
          Color.lerp(navIconInactive, other.navIconInactive, t)!,
      navIconActiveBg:
          Color.lerp(navIconActiveBg, other.navIconActiveBg, t)!,
      navIconActiveFg:
          Color.lerp(navIconActiveFg, other.navIconActiveFg, t)!,
    );
  }
}

/// Shorthand accessor for MoneyTracker glassmorphism tokens.
extension GlassTokensContext on BuildContext {
  GlassTokens get glass =>
      Theme.of(this).extension<GlassTokens>() ?? GlassTokens.light;
}
