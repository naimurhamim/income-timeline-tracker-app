import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entry.dart';
import '../providers/currency_provider.dart';
import '../theme/app_colors.dart';
import 'bouncy_tap.dart';

class UpcomingHeroCard extends StatelessWidget {
  final EntryModel entry;
  final VoidCallback? onTap;
  final VoidCallback? onMarkReceived;

  const UpcomingHeroCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onMarkReceived,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = context.watch<CurrencyProvider>();
    final currencyFormat = NumberFormat.currency(
      locale: currency.locale,
      symbol: currency.symbol,
      decimalDigits: 0,
    );

    return BouncyTap(
      onPressed: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.headerGradientDark
              : AppColors.headerGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryTeal.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentLime.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.upcoming_rounded,
                        color: AppColors.accentLime,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'NEXT INCOMING',
                        style: TextStyle(
                          color: AppColors.accentLime,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onMarkReceived != null)
                  _buildActionButton(),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              currencyFormat.format(entry.amount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              entry.title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoChip(
                  icon: Icons.calendar_today_rounded,
                  label: DateFormat('dd MMM yyyy').format(entry.expectedDate),
                ),
                const SizedBox(width: 12),
                _buildInfoChip(
                  icon: _getStatusIcon(),
                  label: entry.statusText,
                  color: _getStatusColor(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                  icon: Icons.category_rounded,
                  label: entry.type,
                ),
                if (entry.isRecurring) ...[
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    icon: Icons.repeat_rounded,
                    label: _getRecurringLabel(),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onMarkReceived,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.download_done_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                'Mark Received',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final chipColor = color ?? Colors.white.withValues(alpha: 0.9);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: chipColor, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: chipColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon() {
    if (entry.isDueToday) return Icons.today_rounded;
    if (entry.isOverdue) return Icons.warning_rounded;
    return Icons.timelapse_rounded;
  }

  Color _getStatusColor() {
    if (entry.isDueToday) return AppColors.warning;
    if (entry.isOverdue) return AppColors.error;
    return AppColors.accentLime;
  }

  String _getRecurringLabel() {
    switch (entry.recurringType) {
      case 'monthly':
        return 'Monthly';
      case 'quarterly':
        return 'Quarterly';
      case 'half_yearly':
        return 'Half Yearly';
      case 'yearly':
        return 'Yearly';
      default:
        return 'One-time';
    }
  }
}
