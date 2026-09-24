import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../theme/app_colors.dart';
import 'bouncy_tap.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildCard(
              context,
              title: 'This month',
              amount: totalUpcoming,
              currencyFormat: currencyFormat,
              icon: Icons.schedule_rounded,
              color: AppColors.warning,
              theme: theme,
              onTap: onUpcomingTap,
            ),
          ),
          const SizedBox(width: 12),
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
    final isDark = theme.brightness == Brightness.dark;

    return BouncyTap(
      onPressed: onTap,
      scaleDown: 0.98,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: amount),
              duration: const Duration(seconds: 1),
              curve: Curves.easeOutQuart,
              builder: (context, value, child) {
                return Text(
                  currencyFormat.format(value),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
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
