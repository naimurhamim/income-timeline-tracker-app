import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entry.dart';
import '../providers/currency_provider.dart';
import '../theme/app_colors.dart';
import 'bouncy_tap.dart';

class EntryListTile extends StatelessWidget {
  final EntryModel entry;
  final VoidCallback? onTap;
  final VoidCallback? onMarkReceived;

  const EntryListTile({
    super.key,
    required this.entry,
    this.onTap,
    this.onMarkReceived,
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

    return BouncyTap(
      onPressed: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: entry.isOverdue
              ? Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                  width: 1,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Priority indicator + Type icon
            _buildLeadingIcon(theme),
            const SizedBox(width: 14),

            // Title, type, date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration:
                                entry.isReceived ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildPriorityTag(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildTypeBadge(theme),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        DateFormat('dd MMM yy').format(entry.expectedDate),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (entry.isRecurring) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.repeat_rounded,
                          size: 12,
                          color: AppColors.accentLime,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Amount + Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFormat.format(entry.amount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: entry.isReceived
                        ? AppColors.success
                        : theme.textTheme.titleMedium?.color,
                  ),
                ),
                const SizedBox(height: 4),
                _buildStatusBadge(theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(ThemeData theme) {
    final iconColor = _getCategoryColor(theme);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              _getTypeIcon(),
              color: iconColor,
              size: 22,
            ),
          ),
          if (entry.isReceived)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.accentLime.withValues(alpha: 0.2)
            : AppColors.accentLime.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        entry.type,
        style: TextStyle(
          color: isDark ? AppColors.accentLime : AppColors.secondaryGreen,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ThemeData theme) {
    Color color;
    String text;

    if (entry.isReceived) {
      color = AppColors.success;
      text = 'Received';
    } else if (entry.isDueToday) {
      color = AppColors.warning;
      text = 'Due Today';
    } else if (entry.isOverdue) {
      color = AppColors.error;
      text = 'Overdue';
    } else {
      color = AppColors.info;
      text = '${entry.daysRemaining}d left';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  IconData _getTypeIcon() {
    switch (entry.type.toLowerCase()) {
      case 'fd':
        return Icons.account_balance_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'dps':
        return Icons.trending_up_rounded;
      case 'bond':
        return Icons.description_rounded;
      case 'insurance':
        return Icons.security_rounded;
      default:
        return Icons.attach_money_rounded;
    }
  }

  Color _getCategoryColor(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    switch (entry.type.toLowerCase()) {
      case 'fd':
        return isDark ? Colors.cyanAccent : AppColors.primaryTeal;
      case 'savings':
        return isDark ? AppColors.accentLime : AppColors.secondaryGreen;
      case 'dps':
        return isDark ? Colors.lightBlueAccent : AppColors.info;
      case 'bond':
        return isDark ? Colors.purpleAccent : const Color(0xFFAB47BC);
      case 'insurance':
        return isDark ? Colors.orangeAccent : AppColors.warning;
      default:
        return AppColors.accentLime;
    }
  }

  Widget _buildPriorityTag() {
    String label = '';
    Color color = AppColors.primaryTeal;
    
    switch (entry.priority) {
      case 3:
        label = 'H';
        color = AppColors.priorityHigh;
        break;
      case 2:
        label = 'M';
        color = AppColors.priorityMedium;
        break;
      case 1:
        label = 'L';
        color = AppColors.priorityLow;
        break;
    }

    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
