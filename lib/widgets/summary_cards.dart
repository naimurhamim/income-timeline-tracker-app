import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../theme/app_colors.dart';
import '../theme/glass_tokens.dart';
import 'bouncy_tap.dart';
import 'glass_surface.dart';

class SummaryCards extends StatelessWidget {
  final double totalUpcoming;
  final double totalReceived;
  final VoidCallback? onUpcomingTap;
  final VoidCallback? onReceivedTap;

  const SummaryCards({
    super.key,
    required this.totalUpcoming,
    required this.totalReceived,
    this.onUpcomingTap,
    this.onReceivedTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = context.watch<CurrencyProvider>();
    final currencyFormat = NumberFormat.currency(
      locale: currency.locale,
      symbol: currency.symbol,
      decimalDigits: 0,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: _buildCard(
              context,
              title: 'This Month',
              amount: totalUpcoming,
              currencyFormat: currencyFormat,
              icon: Icons.schedule_rounded,
              color: AppColors.warning,
              theme: theme,
              onTap: onUpcomingTap,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _buildCard(
              context,
              title: 'Received',
              amount: totalReceived,
              currencyFormat: currencyFormat,
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
              theme: theme,
              onTap: onReceivedTap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required double amount,
    required NumberFormat currencyFormat,
    required IconData icon,
    required Color color,
    required ThemeData theme,
    VoidCallback? onTap,
  }) {
    final g = context.glass;
    final isDark = theme.brightness == Brightness.dark;
    final adaptedColor = AppColors.adaptiveColor(color, isDark);

    return BouncyTap(
      onPressed: onTap,
      scaleDown: 0.98,
      child: GlassContainer(
        borderRadius: AppRadius.lg,
        blur: 0,
        elevated: true,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: adaptedColor.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, color: adaptedColor, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: g.textSecondary,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: g.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: amount),
              duration: const Duration(milliseconds: 850),
              curve: Curves.easeOutQuart,
              builder: (context, value, child) {
                return Text(
                  currencyFormat.format(value),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: g.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
