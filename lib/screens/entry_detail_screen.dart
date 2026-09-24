import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entry.dart';
import '../providers/entry_provider.dart';
import '../providers/currency_provider.dart';
import '../theme/app_colors.dart';
import 'add_entry_screen.dart';

class EntryDetailScreen extends StatelessWidget {
  final int entryId;

  const EntryDetailScreen({super.key, required this.entryId});

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
    final entryProvider = context.watch<EntryProvider>();
    
    // Find the entry from live provider data
    final entry = entryProvider.entries.cast<EntryModel?>().firstWhere(
      (e) => e!.id == entryId,
      orElse: () => null,
    );
    
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text('Entry not found or deleted')),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor:
                isDark ? AppColors.primaryTealDark : AppColors.primaryTeal,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEntryScreen(editEntry: entry),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded, color: Colors.white),
                onPressed: () => _confirmDelete(context, entry),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? AppColors.headerGradientDark
                      : AppColors.headerGradient,
                ),
                child: SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 30),
                        Text(
                          currencyFormat.format(entry.amount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.title,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Status Card
                  _buildStatusCard(theme, entry),
                  const SizedBox(height: 16),

                  // Details Card
                  _buildDetailsCard(theme, currencyFormat, entry),
                  const SizedBox(height: 16),

                  // Notes Card
                  if (entry.notes != null && entry.notes!.isNotEmpty)
                    _buildNotesCard(theme, entry),

                  const SizedBox(height: 24),

                  // Action Buttons
                  _buildActionButtons(context, theme, entry),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme, EntryModel entry) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (entry.isReceived) {
      statusColor = AppColors.success;
      statusText = 'Received on ${DateFormat('dd MMM yyyy').format(entry.receivedDate ?? DateTime.now())}';
      statusIcon = Icons.check_circle_rounded;
    } else if (entry.isDueToday) {
      statusColor = AppColors.warning;
      statusText = 'Due Today!';
      statusIcon = Icons.today_rounded;
    } else if (entry.isOverdue) {
      statusColor = AppColors.error;
      statusText = 'Overdue by ${-entry.daysRemaining} days';
      statusIcon = Icons.warning_rounded;
    } else {
      statusColor = AppColors.info;
      statusText = '${entry.daysRemaining} days remaining';
      statusIcon = Icons.timelapse_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(ThemeData theme, NumberFormat currencyFormat, EntryModel entry) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        children: [
          _buildDetailRow(theme, 'Category', entry.type,
              Icons.category_rounded),
          const Divider(height: 24),
          _buildDetailRow(
            theme,
            'Expected Date',
            DateFormat('EEEE, dd MMMM yyyy').format(entry.expectedDate),
            Icons.calendar_today_rounded,
          ),
          const Divider(height: 24),
          _buildDetailRow(
            theme,
            'Priority',
            _getPriorityLabel(entry),
            Icons.flag_rounded,
          ),
          if (entry.isRecurring) ...[
            const Divider(height: 24),
            _buildDetailRow(
              theme,
              'Recurring',
              _getRecurringLabel(entry),
              Icons.repeat_rounded,
            ),
          ],
          const Divider(height: 24),
          _buildDetailRow(
            theme,
            'Created',
            DateFormat('dd MMM yyyy, HH:mm').format(entry.createdAt),
            Icons.access_time_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      ThemeData theme, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.textTheme.bodySmall?.color),
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
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesCard(ThemeData theme, EntryModel entry) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
              Icon(Icons.notes_rounded,
                  size: 20, color: theme.textTheme.bodySmall?.color),
              const SizedBox(width: 8),
              Text('Notes', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.notes!,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ThemeData theme, EntryModel entry) {
    final provider = context.read<EntryProvider>();

    if (entry.isReceived) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton.icon(
          onPressed: () {
            provider.markUnreceived(entry.id!);
            Navigator.pop(context);
          },
          icon: const Icon(Icons.undo_rounded),
          label: const Text('Mark as Unreceived'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.warning),
            foregroundColor: AppColors.warning,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () {
          provider.markReceived(entry.id!);
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              context.read<EntryProvider>().deleteEntry(entry.id!);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
