import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entry.dart';
import '../providers/currency_provider.dart';
import '../theme/app_colors.dart';
import '../theme/glass_tokens.dart';
import 'bouncy_tap.dart';
import 'glass_surface.dart';

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
    final g = context.glass;
    final currency = context.watch<CurrencyProvider>();
    final currencyFormat = NumberFormat.currency(
      locale: currency.locale,
      symbol: currency.symbol,
      decimalDigits: 0,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 5),
      child: BouncyTap(
        onPressed: onTap,
        child: GlassContainer(
          borderRadius: AppRadius.lg,
          blur: 0,
          elevated: true,
          borderColor: entry.isOverdue
              ? g.danger.withValues(alpha: 0.4)
              : g.glassBorder,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _buildLeadingIcon(context, theme),
              const SizedBox(width: 14),
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
                              fontWeight: FontWeight.w700,
                              decoration: entry.isReceived
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildPriorityTag(),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _buildTypeBadge(theme),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: g.textSecondary,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            DateFormat('dd MMM yy').format(entry.expectedDate),
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.isRecurring) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.repeat_rounded,
                            size: 13,
                            color: g.primary,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormat.format(entry.amount),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: entry.isReceived ? g.success : g.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildStatusBadge(context),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(BuildContext context, ThemeData theme) {
    final g = context.glass;
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = _getCategoryColor(isDark);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: iconColor.withValues(alpha: isDark ? 0.42 : 0.2),
        ),
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
                  color: g.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: g.surface, width: 2),
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
    final badgeColor =
        isDark ? AppColors.accentMintLight : AppColors.deepForest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        entry.type,
        style: TextStyle(
          color: badgeColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final g = context.glass;
    final Color color;
    final String text;

    if (entry.isReceived) {
      color = g.success;
      text = 'Received';
    } else if (entry.isDueToday) {
      color = g.warning;
      text = 'Due Today';
    } else if (entry.isOverdue) {
      color = g.danger;
      text = 'Overdue';
    } else {
      color = AppColors.info;
      text = '${entry.daysRemaining}d left';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
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

  Color _getCategoryColor(bool isDark) {
    switch (entry.type.toLowerCase()) {
      case 'fd':
        return AppColors.adaptiveColor(AppColors.primaryTeal, isDark);
      case 'savings':
        return AppColors.adaptiveColor(AppColors.secondaryGreen, isDark);
      case 'dps':
        return AppColors.adaptiveColor(AppColors.info, isDark);
      case 'bond':
        return AppColors.adaptiveColor(const Color(0xFFAB47BC), isDark);
      case 'insurance':
        return AppColors.adaptiveColor(AppColors.warning, isDark);
      default:
        return AppColors.adaptiveColor(AppColors.primaryTeal, isDark);
    }
  }

  Widget _buildPriorityTag() {
    var label = '';
    var color = AppColors.primaryTeal;

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
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
