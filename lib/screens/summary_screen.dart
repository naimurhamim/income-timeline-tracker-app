import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../providers/entry_provider.dart';
import '../providers/investment_provider.dart';
import '../theme/app_colors.dart';
import '../theme/glass_tokens.dart';
import '../widgets/finance_charts.dart';
import '../widgets/glass_surface.dart';
import 'add_investment_screen.dart';

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
    final g = context.glass;
    final isDark = theme.brightness == Brightness.dark;
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.railBreakpoint;
    final currency = context.watch<CurrencyProvider>();
    final currencyFormat = NumberFormat.currency(
      locale: currency.locale,
      symbol: currency.symbol,
      decimalDigits: 0,
    );
    final entryProvider = context.watch<EntryProvider>();
    final investmentProvider = context.watch<InvestmentProvider>();

    final monthlySummary = entryProvider.getEstimatedMonthlySummary(_selectedYear);
    final amountByType = entryProvider.getEstimatedAmountByType(_selectedYear);
    final totalByType =
        amountByType.values.fold<double>(0, (sum, v) => sum + v);
    final chartPoints = monthlySummary.map((m) {
      final monthNum = m['month'] as int;
      final dt = DateTime(_selectedYear, monthNum);
      return MonthlyChartPoint(
        shortLabel: DateFormat.MMMM().format(dt).substring(0, 1),
        fullLabel: DateFormat.MMMM().format(dt),
        received: m['received'] as double,
        upcoming: m['upcoming'] as double,
      );
    }).toList();
    final donutSegments = amountByType.entries
        .map(
          (e) => DonutSegment(
            label: e.key,
            value: e.value,
            color: _getCategoryColor(e.key, isDark),
          ),
        )
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
            child: CustomScrollView(
              slivers: [
                // ─── Top Header ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: Text(
                      'Summary',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                // ─── Year Selector ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xs,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GlassCircleButton(
                          icon: Icons.chevron_left_rounded,
                          tooltip: 'Previous year',
                          size: 40,
                          onTap: () => setState(() => _selectedYear--),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        GlassContainer(
                          borderRadius: AppRadius.pill,
                          blur: 0,
                          elevated: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          child: Text(
                            '$_selectedYear',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        GlassCircleButton(
                          icon: Icons.chevron_right_rounded,
                          tooltip: 'Next year',
                          size: 40,
                          onTap: () => setState(() => _selectedYear++),
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── Yearly Totals ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTotalCard(
                            theme,
                            g,
                            isDark,
                            'Est. This Year',
                            currencyFormat.format(
                              entryProvider
                                  .getEstimatedYearlyTotal(_selectedYear),
                            ),
                            Icons.schedule_rounded,
                            AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _buildTotalCard(
                            theme,
                            g,
                            isDark,
                            'Received',
                            currencyFormat.format(
                              entryProvider.getYearlyReceived(_selectedYear),
                            ),
                            Icons.check_circle_rounded,
                            AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── Principal Invested Overview ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      0,
                    ),
                    child: GlassContainer(
                      borderRadius: AppRadius.lg,
                      blur: 0,
                      elevated: true,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: g.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet_rounded,
                              color: g.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Principal Invested (All Time)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatInvestmentAmount(
                                    currency,
                                    investmentProvider.totalInvested,
                                  ),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${investmentProvider.allInvestments.length} items',
                            style: theme.textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ─── Monthly Cashflow Chart ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                    child: Text(
                      'Monthly Cashflow ($_selectedYear)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: GlassContainer(
                      borderRadius: AppRadius.lg,
                      blur: 0,
                      elevated: true,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: MonthlyBarChart(
                        points: chartPoints,
                        formatAmount: (v) => formatInvestmentAmount(currency, v),
                      ),
                    ),
                  ),
                ),

                // ─── By Category ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                    child: Text(
                      'Income by Category',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                if (amountByType.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg),
                      child: GlassContainer(
                        borderRadius: AppRadius.lg,
                        blur: 0,
                        elevated: true,
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Center(
                          child: Text(
                            'No income data for $_selectedYear',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: GlassContainer(
                        borderRadius: AppRadius.lg,
                        blur: 0,
                        elevated: true,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: [
                            CategoryDonutChart(
                              segments: donutSegments,
                              centerValue: currency.compact(totalByType),
                              centerLabel: '$_selectedYear',
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Divider(height: 1, color: g.border),
                            const SizedBox(height: AppSpacing.sm),
                            ...amountByType.entries.map((e) {
                              final percentage = totalByType > 0
                                  ? (e.value / totalByType * 100)
                                  : 0.0;
                              final barColor =
                                  _getCategoryColor(e.key, isDark);

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          e.key,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          currencyFormat.format(e.value),
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: percentage / 100,
                                        minHeight: 7,
                                        backgroundColor: g.surfaceSubtle,
                                        color: barColor,
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
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ─── Monthly Breakdown ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                    child: Text(
                      'Monthly Breakdown',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final month = monthlySummary[index];
                      final monthName = DateFormat.MMMM().format(
                        DateTime(_selectedYear, month['month'] as int),
                      );
                      final received = month['received'] as double;
                      final upcoming = month['upcoming'] as double;

                      if (received == 0 && upcoming == 0) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: 4,
                        ),
                        child: GlassContainer(
                          borderRadius: AppRadius.md,
                          blur: 0,
                          elevated: true,
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: g.primarySoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    DateFormat.MMM().format(
                                      DateTime(
                                        _selectedYear,
                                        month['month'] as int,
                                      ),
                                    ),
                                    style: TextStyle(
                                      color: g.primary,
                                      fontWeight: FontWeight.w800,
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
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (upcoming > 0) ...[
                                          Icon(Icons.schedule_rounded,
                                              size: 12, color: g.warning),
                                          const SizedBox(width: 4),
                                          Text(
                                            currencyFormat.format(upcoming),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: g.warning,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                        if (upcoming > 0 && received > 0)
                                          const SizedBox(width: 12),
                                        if (received > 0) ...[
                                          Icon(Icons.check_circle_rounded,
                                              size: 12, color: g.success),
                                          const SizedBox(width: 4),
                                          Text(
                                            currencyFormat.format(received),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: g.success,
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
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: monthlySummary.length,
                  ),
                ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: wide ? AppSpacing.xl : AppLayout.navClearance + 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalCard(
    ThemeData theme,
    GlassTokens g,
    bool isDark,
    String title,
    String amount,
    IconData icon,
    Color color,
  ) {
    final adapted = AppColors.adaptiveColor(color, isDark);
    return GlassContainer(
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: adapted.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: adapted, size: 18),
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
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: g.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String type, bool isDark) {
    switch (type.toLowerCase()) {
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
        return AppColors.adaptiveColor(AppColors.accentLavender, isDark);
    }
  }
}
