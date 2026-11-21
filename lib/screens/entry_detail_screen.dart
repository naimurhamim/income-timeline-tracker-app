import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entry.dart';
import '../providers/currency_provider.dart';
import '../providers/entry_provider.dart';
import '../theme/app_colors.dart';
import '../theme/glass_tokens.dart';
import '../widgets/glass_surface.dart';
import 'add_entry_screen.dart';

class EntryDetailScreen extends StatelessWidget {
  final String entryId;

  const EntryDetailScreen({super.key, required this.entryId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = context.glass;
    final isDark = theme.brightness == Brightness.dark;
    final currency = context.watch<CurrencyProvider>();
    final currencyFormat = NumberFormat.currency(
      locale: currency.locale,
      symbol: currency.symbol,
      decimalDigits: 0,
    );
    final entryProvider = context.watch<EntryProvider>();

    final entry = entryProvider.entries.cast<EntryModel?>().firstWhere(
          (e) => e!.id == entryId,
          orElse: () => null,
        );

    if (entry == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: GlassBackdrop(
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: GlassCircleButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ),
                const Expanded(
                  child: Center(child: Text('Entry not found or deleted')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          GlassCircleButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Back',
                            size: 42,
                            onTap: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          GlassCircleButton(
                            icon: Icons.edit_rounded,
                            tooltip: 'Edit Entry',
                            size: 42,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AddEntryScreen(editEntry: entry),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          GlassCircleButton(
                            icon: Icons.delete_outline_rounded,
                            iconColor: g.danger,
                            tooltip: 'Delete Entry',
                            size: 42,
                            onTap: () => _confirmDelete(context, entry),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: isDark
                              ? AppColors.headerGradientDark
                              : AppColors.headerGradient,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(
                            color: Colors.white
                                .withValues(alpha: isDark ? 0.16 : 0.24),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              currencyFormat.format(entry.amount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              entry.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        children: [
                          _buildStatusCard(theme, g, entry),
                          const SizedBox(height: AppSpacing.md),
                          _buildDetailsCard(
                              theme, g, currencyFormat, entry),
                          if (entry.notes != null &&
                              entry.notes!.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            _buildNotesCard(theme, g, entry),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          _buildActionButtons(context, g, entry),
                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(
      ThemeData theme, GlassTokens g, EntryModel entry) {
    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    if (entry.isReceived) {
      statusColor = g.success;
      statusText =
          'Received on ${DateFormat('dd MMM yyyy').format(entry.receivedDate ?? DateTime.now())}';
      statusIcon = Icons.check_circle_rounded;
    } else if (entry.isDueToday) {
      statusColor = g.warning;
      statusText = 'Due Today!';
      statusIcon = Icons.today_rounded;
    } else if (entry.isOverdue) {
      statusColor = g.danger;
      statusText = 'Overdue by ${-entry.daysRemaining} days';
      statusIcon = Icons.warning_rounded;
    } else {
      statusColor = AppColors.info;
      statusText = '${entry.daysRemaining} days remaining';
      statusIcon = Icons.timelapse_rounded;
    }

    return GlassContainer(
      borderRadius: AppRadius.md,
      blur: 0,
      fillColor: statusColor.withValues(alpha: 0.14),
      borderColor: statusColor.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(
    ThemeData theme,
    GlassTokens g,
    NumberFormat currencyFormat,
    EntryModel entry,
  ) {
    return GlassContainer(
      borderRadius: AppRadius.lg,
      blur: 0,
      elevated: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildDetailRow(
              theme, g, 'Category', entry.type, Icons.category_rounded),
          const Divider(height: 24),
          _buildDetailRow(
            theme,
            g,
            'Expected Date',
            DateFormat('EEEE, dd MMMM yyyy').format(entry.expectedDate),
            Icons.calendar_today_rounded,
          ),
          const Divider(height: 24),
          _buildDetailRow(
            theme,
            g,
            'Priority',
            _getPriorityLabel(entry),
            Icons.flag_rounded,
          ),
          if (entry.isRecurring) ...[
            const Divider(height: 24),
            _buildDetailRow(
              theme,
              g,
              'Recurring',
              _getRecurringLabel(entry),
              Icons.repeat_rounded,
            ),
          ],
          const Divider(height: 24),
          _buildDetailRow(
            theme,
            g,
            'Created',
            DateFormat('dd MMM yyyy, HH:mm').format(entry.createdAt),
            Icons.access_time_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    ThemeData theme,
    GlassTokens g,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: g.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesCard(
      ThemeData theme, GlassTokens g, EntryModel entry) {
    return GlassContainer(
      borderRadius: AppRadius.lg,
      blur: 0,
      elevated: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded, size: 20, color: g.textSecondary),
              const SizedBox(width: 8),
              Text('Notes', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Text(entry.notes!, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, GlassTokens g, EntryModel entry) {
    final provider = context.read<EntryProvider>();

    if (entry.isReceived) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: OutlinedButton.icon(
          onPressed: () {
            provider.markUnreceived(entry.id);
            Navigator.pop(context);
          },
          icon: const Icon(Icons.undo_rounded),
          label: const Text('Mark as Unreceived'),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: g.warning),
            foregroundColor: g.warning,
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: () {
          provider.markReceived(entry.id);
          Navigator.pop(context);
        },
        icon: const Icon(Icons.check_rounded),
        label: const Text('Mark as Received'),
      ),
    );
  }

  String _getPriorityLabel(EntryModel entry) {
    switch (entry.priority) {
      case 3:
        return 'High';
      case 2:
        return 'Medium';
      case 1:
        return 'Low';
      default:
        return 'Medium';
    }
  }

  String _getRecurringLabel(EntryModel entry) {
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
        return 'None';
    }
  }

  void _confirmDelete(BuildContext context, EntryModel entry) {
    final g = context.glass;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: g.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: g.glassBorder),
        ),
        title: const Text('Delete Entry?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<EntryProvider>().deleteEntry(entry.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
