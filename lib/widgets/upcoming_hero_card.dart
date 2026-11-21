import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entry.dart';
import '../providers/currency_provider.dart';
import '../theme/app_colors.dart';
import '../theme/glass_tokens.dart';
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
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF102A1C),
                    Color(0xFF0A1811),
                  ],
                )
              : AppColors.lightForestHeroGradient,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: isDark
                ? AppColors.accentMintLight.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.22),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : AppColors.deepForest)
                  .withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 10),
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
                    color: AppColors.accentMintLight.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: AppColors.accentMintLight.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.upcoming_rounded,
                        color: AppColors.accentMintLight,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'NEXT INCOMING',
                        style: TextStyle(
                          color: AppColors.accentMintLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onMarkReceived != null) _buildActionButton(),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              currencyFormat.format(entry.amount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.9,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              entry.title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  icon: Icons.calendar_today_rounded,
                  label: DateFormat('dd MMM yyyy').format(entry.expectedDate),
                ),
                _buildInfoChip(
                  icon: _getStatusIcon(),
                  label: entry.statusText,
                  color: _getStatusColor(),
                ),
                _buildInfoChip(
                  icon: Icons.category_rounded,
                  label: entry.type,
                ),
                if (entry.isRecurring)
                  _buildInfoChip(
                    icon: Icons.repeat_rounded,
                    label: _getRecurringLabel(),
                  ),
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
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.45),
              width: 1.2,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.download_done_rounded,
                color: Colors.white,
                size: 15,
              ),
              SizedBox(width: 5),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: chipColor, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    if (entry.isDueToday) return Icons.today_rounded;
    if (entry.isOverdue) return Icons.warning_rounded;
    return Icons.timelapse_rounded;
  }

  Color _getStatusColor() {
    if (entry.isDueToday) return AppColors.warning;
    if (entry.isOverdue) return const Color(0xFFFF8A80);
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
