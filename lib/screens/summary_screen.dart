import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/entry_provider.dart';
import '../providers/currency_provider.dart';
import '../theme/app_colors.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  int _selectedYear = DateTime.now().year;

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
    
    final monthlySummary = entryProvider.getEstimatedMonthlySummary(_selectedYear);
    final amountByType = entryProvider.getEstimatedAmountByType(_selectedYear);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── App Bar ───
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor:
                isDark ? AppColors.primaryTealDark : AppColors.primaryTeal,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? AppColors.headerGradientDark
                      : AppColors.headerGradient,
                ),
              ),
            ),
          ),

          // ─── Year Selector ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() => _selectedYear--);
                    },
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_selectedYear',
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _selectedYear++);
                    },
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
          ),

          // ─── Total Summary Cards ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTotalCard(
                      theme,
                      'Est. This Year',
                      currencyFormat.format(entryProvider.getEstimatedYearlyTotal(_selectedYear)),
                      Icons.schedule_rounded,
                      AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTotalCard(
                      theme,
                      'Received',
                      currencyFormat.format(entryProvider.getYearlyReceived(_selectedYear)),
                      Icons.check_circle_rounded,
                      AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── By Category ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                'By Category',
                style: theme.textTheme.headlineMedium,
              ),
            ),
          ),

          if (amountByType.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No data available',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    children: amountByType.entries.map((e) {
                      final total = amountByType.values.fold<double>(
                        0,
                        (sum, v) => sum + v,
                      );
                      final percentage =
                          total > 0 ? (e.value / total * 100) : 0.0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  e.key,
                                  style: theme.textTheme.titleMedium,
                                ),
                                Text(
                                  currencyFormat.format(e.value),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                minHeight: 6,
                                backgroundColor: theme
                                    .inputDecorationTheme.fillColor,
                                color: _getCategoryColor(e.key),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${percentage.toStringAsFixed(1)}%',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

          // ─── Monthly Breakdown ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                'Monthly Breakdown',
                style: theme.textTheme.headlineMedium,
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                  final month = monthlySummary[index];
                  final monthName = DateFormat.MMMM()
                      .format(DateTime(_selectedYear, month['month'] as int));
                  final received = month['received'] as double;
                  final upcoming = month['upcoming'] as double;

                  if (received == 0 && upcoming == 0) {
                    return const SizedBox.shrink();
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
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
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.accentLime.withValues(alpha: 0.15)
                                : AppColors.primaryTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              DateFormat.MMM().format(DateTime(
                                  _selectedYear, month['month'] as int)),
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.accentLime
                                    : AppColors.primaryTeal,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                monthName,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (upcoming > 0) ...[
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 12,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      currencyFormat.format(upcoming),
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.warning,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  if (upcoming > 0 && received > 0)
                                    const SizedBox(width: 12),
                                  if (received > 0) ...[
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 12,
                                      color: AppColors.success,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      currencyFormat.format(received),
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          currencyFormat.format(upcoming + received),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                childCount: monthlySummary.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildTotalCard(
    ThemeData theme,
    String title,
    String amount,
    IconData icon,
    Color color,
  ) {
    return Container(
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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String type) {
    switch (type.toLowerCase()) {
      case 'fd':
        return AppColors.info;
      case 'savings':
        return AppColors.success;
      case 'dps':
        return AppColors.info;
      case 'bond':
        return const Color(0xFFAB47BC);
      case 'insurance':
        return AppColors.warning;
      default:
        return AppColors.accentLavender;
    }
  }
}
