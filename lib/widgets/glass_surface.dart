import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/glass_tokens.dart';

/// Soft gradient + ambient orb backdrop shared across screens and pushed routes.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: dark
                      ? const RadialGradient(
                          center: Alignment(0.0, -0.78),
                          radius: 1.05,
                          colors: [
                            Color(0xFF1A4E32),
                            Color(0xFF0C2216),
                            Color(0xFF050907),
                          ],
                          stops: [0.0, 0.42, 1.0],
                        )
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            g.bgGradientTop,
                            g.bg,
                            g.bgGradientBottom,
                          ],
                        ),
                ),
              ),
              Positioned(
                top: -110,
                left: -60,
                child: _AmbientOrb(
                  size: 290,
                  color: g.orbPrimary.withValues(alpha: dark ? 0.28 : 0.24),
                ),
              ),
              Positioned(
                top: 120,
                right: -110,
                child: _AmbientOrb(
                  size: 310,
                  color: g.orbAccent.withValues(alpha: dark ? 0.12 : 0.14),
                ),
              ),
              Positioned(
                bottom: -120,
                left: 20,
                child: _AmbientOrb(
                  size: 290,
                  color: g.orbSecondary.withValues(alpha: dark ? 0.22 : 0.18),
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// Frosted translucent glass card container with optional tap feedback.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = AppRadius.lg,
    this.blur = 0,
    this.elevated = false,
    this.borderColor,
    this.fillColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double blur;
  final bool elevated;
  final Color? borderColor;
  final Color? fillColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final radius = BorderRadius.circular(borderRadius);
    final effectiveFill =
        fillColor ?? (elevated ? g.glassFillElevated : g.glassFill);
    final effectiveBorder = borderColor ?? g.glassBorder;
    final useGradient = blur <= 0 && fillColor == null;

    final inner = Container(
      decoration: BoxDecoration(
        color: useGradient ? null : effectiveFill,
        gradient: useGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [effectiveFill, g.glassFill],
              )
            : null,
        borderRadius: radius,
        border: Border.all(color: effectiveBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: g.glassShadow,
            blurRadius: blur > 0 ? 18 : 12,
            offset: Offset(0, blur > 0 ? 6 : 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: child,
                ),
              )
            : Padding(
                padding: padding ?? EdgeInsets.zero,
                child: child,
              ),
      ),
    );

    if (blur <= 0) return inner;

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: inner,
      ),
    );
  }
}

/// Circular frosted glass button with optional numeric badge.
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.badgeCount = 0,
    this.size = 44,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final int badgeCount;
  final double size;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Semantics(
      label: tooltip,
      button: true,
      child: Tooltip(
        message: tooltip,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GlassContainer(
              borderRadius: AppRadius.pill,
              blur: 0,
              elevated: true,
              onTap: onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(
                  icon,
                  size: AppIconSize.md,
                  color: iconColor ?? g.textPrimary,
                ),
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: g.danger,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: g.surface, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact frosted pill button for quick actions.
class GlassPillButton extends StatelessWidget {
  const GlassPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return GlassContainer(
      borderRadius: AppRadius.pill,
      blur: 0,
      elevated: !selected,
      fillColor: selected ? g.primary : null,
      borderColor: selected ? g.primary : g.glassBorder,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: selected ? g.onPrimary : (iconColor ?? g.textPrimary),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? g.onPrimary : g.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the app icon inside a crisp frosted rounded badge.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: g.glassFillElevated,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: g.glassBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: g.glassShadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/app_icon.png',
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(
          Icons.account_balance_wallet_rounded,
          color: g.primary,
          size: size * 0.55,
        ),
      ),
    );
  }
}
