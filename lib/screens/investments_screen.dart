import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/investment.dart';
import '../providers/currency_provider.dart';
import '../providers/investment_provider.dart';
import '../theme/app_colors.dart';
import '../theme/glass_tokens.dart';
import '../widgets/bouncy_tap.dart';
import '../widgets/calculator_keyboard.dart';
import '../widgets/finance_charts.dart';
import '../widgets/glass_surface.dart';
import 'add_investment_screen.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _quickEditAmount(
    BuildContext context,
    InvestmentModel inv,
    InvestmentProvider provider,
    CurrencyProvider currency,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final newAmount = await showCalculatorKeyboard(
      context,
      initialValue: inv.amount,
      title: inv.title,
      currencySymbol: currency.symbol,
      formatAmount: (v) => formatInvestmentAmount(currency, v),
    );
    if (newAmount == null || !context.mounted) return;
    if ((newAmount - inv.amount).abs() < 0.01) return;

    final confirmed = await showAmountVerificationDialog(
      context,
      title: inv.title,
      oldAmount: inv.amount,
      newAmount: newAmount,
      currency: currency,
    );
    if (!confirmed || !context.mounted) return;

    await provider.updateInvestment(
      inv.copyWith(amount: newAmount, updatedAt: DateTime.now()),
    );
    if (!context.mounted) return;
    showAmountUpdatedSnackBar(
      context,
      title: inv.title,
      oldAmount: inv.amount,
      newAmount: newAmount,
      currency: currency,
      messenger: messenger,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    InvestmentModel inv,
    InvestmentProvider provider,
    CurrencyProvider currency,
  ) async {
    final g = context.glass;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: g.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: g.glassBorder),
        ),
        title: const Text('Delete Investment?'),
        content: Text(
          'Remove "${inv.title}" (${formatInvestmentAmount(currency, inv.amount)}) from your principal investments?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await provider.deleteInvestment(inv.id);
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Deleted "${inv.title}"'),
        ),
      );
  }

  void _openAddScreen({InvestmentModel? edit}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddInvestmentScreen(editInvestment: edit),
      ),
    );
  }

  void _clearFilters(InvestmentProvider provider) {
    if (provider.selectedTypeFilter != null) {
      provider.setTypeFilter(null);
    }
    if (_isSearching || provider.searchQuery.isNotEmpty) {
      setState(() {
        _isSearching = false;
        _searchController.clear();
      });
      provider.setSearchQuery('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = context.glass;
    final isDark = theme.brightness == Brightness.dark;
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.railBreakpoint;
    final provider = context.watch<InvestmentProvider>();
    final currency = context.watch<CurrencyProvider>();

    final all = provider.allInvestments;
    final filtered = provider.filteredInvestments;
    final totalsByType = provider.totalsByType;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
            child: RefreshIndicator(
              onRefresh: () => provider.loadInvestments(preferServer: true),
              color: g.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ─── Glass Top Header ───
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _isSearching
                                ? GlassContainer(
                                    borderRadius: AppRadius.pill,
                                    blur: 0,
                                    elevated: true,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg,
                                      vertical: 2,
                                    ),
                                    child: TextField(
                                      controller: _searchController,
                                      autofocus: true,
                                      decoration: const InputDecoration(
                                        hintText: 'Search investments...',
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        filled: false,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: provider.setSearchQuery,
                                    ),
                                  )
                                : Text(
                                    'Investments',
                                    style:
                                        theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          GlassCircleButton(
                            icon: _isSearching
                                ? Icons.close_rounded
                                : Icons.search_rounded,
                            tooltip:
                                _isSearching ? 'Close search' : 'Search',
                            size: 42,
                            onTap: () {
                              setState(() {
                                _isSearching = !_isSearching;
                                if (!_isSearching) {
                                  _searchController.clear();
                                  provider.setSearchQuery('');
                                }
                              });
                            },
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          GlassPillButton(
                            icon: Icons.add_rounded,
                            label: 'Add',
                            selected: true,
                            onTap: () => _openAddScreen(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─── Hero Summary Card ───
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xs,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: _buildHeroCard(
                        theme: theme,
                        isDark: isDark,
                        provider: provider,
                        currency: currency,
                        typeCount: totalsByType.length,
                      )
                          .animate()
                          .fade(duration: 380.ms)
                          .slideY(
                            begin: 0.08,
                            end: 0,
                            curve: Curves.easeOutQuad,
                          ),
                    ),
                  ),

                  // ─── Portfolio Allocation Donut (when 2+ types) ───
                  if (totalsByType.length >= 2)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.xs,
                          AppSpacing.lg,
                          AppSpacing.sm,
                        ),
                        child: _buildAllocationCard(
                          theme: theme,
                          g: g,
                          provider: provider,
                          currency: currency,
                          totalsByType: totalsByType,
                        ),
                      ),
                    ),

                  // ─── Breakdown & Filter Chips ───
                  if (all.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildTypeFilterBar(
                        theme: theme,
                        isDark: isDark,
                        provider: provider,
                        currency: currency,
                        totalsByType: totalsByType,
                      ),
                    ),

                  // ─── Content ───
                  if (all.isEmpty && !provider.isLoading)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(theme, g),
                    )
                  else if (filtered.isEmpty && !provider.isLoading)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildFilteredEmptyState(theme, g, provider),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              provider.selectedTypeFilter != null
                                  ? '${provider.selectedTypeFilter} Records'
                                  : 'Portfolio Records',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Tap amount to calculate',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final inv = filtered[index];
                          return Slidable(
                            key: ValueKey(inv.id),
                            endActionPane: ActionPane(
                              motion: const BehindMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (_) => _openAddScreen(edit: inv),
                                  backgroundColor: AppColors.info,
                                  foregroundColor: Colors.white,
                                  icon: Icons.edit_rounded,
                                  label: 'Edit',
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                SlidableAction(
                                  onPressed: (_) => _confirmDelete(
                                      context, inv, provider, currency),
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete_rounded,
                                  label: 'Delete',
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ],
                            ),
                            child: _InvestmentTile(
                              investment: inv,
                              currency: currency,
                              onTapCard: () => _openAddScreen(edit: inv),
                              onTapAmount: () => _quickEditAmount(
                                  context, inv, provider, currency),
                            ),
                          );
                        },
                        childCount: filtered.length,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height:
                            wide ? AppSpacing.xl : AppLayout.navClearance + 36,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard({
    required ThemeData theme,
    required bool isDark,
    required InvestmentProvider provider,
    required CurrencyProvider currency,
    required int typeCount,
  }) {
    final totalCount = provider.allInvestments.length;
    final hasFilter =
        provider.selectedTypeFilter != null || provider.searchQuery.isNotEmpty;
    final heroFg = isDark ? const Color(0xFF06160C) : Colors.white;
    final heroSubFg = isDark
        ? const Color(0xCC06160C)
        : Colors.white.withValues(alpha: 0.78);
    final pillBg = isDark
        ? const Color(0xFF06160C).withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.16);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.darkMintHeroGradient
            : AppColors.lightForestHeroGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.45 : 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.accentMintLight : AppColors.deepForest)
                .withValues(alpha: isDark ? 0.24 : 0.28),
            blurRadius: 22,
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
              Text(
                'Total Invested',
                style: TextStyle(
                  color: heroSubFg,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      color: isDark ? heroFg : AppColors.accentMintLight,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Principal Capital',
                      style: TextStyle(
                        color: heroFg,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatInvestmentAmount(currency, provider.totalInvested),
              style: TextStyle(
                color: heroFg,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.9,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '$totalCount ${totalCount == 1 ? 'record' : 'records'} · $typeCount ${typeCount == 1 ? 'type' : 'types'}',
                style: TextStyle(
                  color: heroSubFg,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hasFilter) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.obsidianCardDark
                        : const Color(0xFF0E3422),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${provider.selectedTypeFilter ?? 'Search'}: ${formatInvestmentAmount(currency, provider.filteredTotal)}',
                    style: const TextStyle(
                      color: AppColors.accentMintLight,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationCard({
    required ThemeData theme,
    required GlassTokens g,
    required InvestmentProvider provider,
    required CurrencyProvider currency,
    required Map<String, double> totalsByType,
  }) {
    final presetsByKey = {
      for (final p in provider.allAvailableTypePresets)
        p.name.trim().toLowerCase(): p,
    };
    final segments = totalsByType.entries.map((entry) {
      final preset = presetsByKey[entry.key.trim().toLowerCase()];
      return DonutSegment(
        label: entry.key,
        value: entry.value,
        color: preset?.displayColor ?? AppColors.deepForest,
      );
    }).toList();

    return GlassContainer(
      borderRadius: AppRadius.xl,
      blur: 0,
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Portfolio Allocation',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          CategoryDonutChart(
            segments: segments,
            centerValue: currency.compact(provider.totalInvested),
            centerLabel: 'Principal',
            size: 114,
            strokeWidth: 15,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterBar({
    required ThemeData theme,
    required bool isDark,
    required InvestmentProvider provider,
    required CurrencyProvider currency,
    required Map<String, double> totalsByType,
  }) {
    final g = context.glass;
    final total = provider.totalInvested;
    final presetsByKey = {
      for (final p in provider.allAvailableTypePresets)
        p.name.trim().toLowerCase(): p,
    };

    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 6),
        children: [
          _buildFilterChip(
            theme: theme,
            g: g,
            isDark: isDark,
            label: 'All (${provider.allInvestments.length})',
            icon: Icons.apps_rounded,
            color: g.primary,
            isSelected: provider.selectedTypeFilter == null,
            onTap: () => provider.setTypeFilter(null),
          ),
          const SizedBox(width: 8),
          ...totalsByType.entries.map((entry) {
            final typeName = entry.key;
            final typeAmount = entry.value;
            final pct = total > 0 ? ((typeAmount / total) * 100).round() : 0;
            final preset = presetsByKey[typeName.trim().toLowerCase()];
            final color = AppColors.adaptiveColor(
              preset?.displayColor ?? AppColors.primaryTeal,
              isDark,
            );
            final icon = InvestmentModel.iconDataFor(preset?.icon ?? 'wallet');
            final isSelected = provider.selectedTypeFilter?.toLowerCase() ==
                typeName.trim().toLowerCase();

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFilterChip(
                theme: theme,
                g: g,
                isDark: isDark,
                label: '$typeName · ${currency.compact(typeAmount)} ($pct%)',
                icon: icon,
                color: color,
                isSelected: isSelected,
                onTap: () => provider.setTypeFilter(typeName),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required ThemeData theme,
    required GlassTokens g,
    required bool isDark,
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final selectedFg =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : const Color(0xFF06160C);
    return GlassContainer(
      borderRadius: AppRadius.pill,
      blur: 0,
      elevated: !isSelected,
      fillColor: isSelected ? color : null,
      borderColor: isSelected ? color : g.glassBorder,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: isSelected ? selectedFg : g.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? selectedFg : g.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, GlassTokens g) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        child: GlassContainer(
          borderRadius: AppRadius.lg,
          blur: 0,
          elevated: true,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: g.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 38,
                  color: g.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text('No Investments Yet', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Track your principal capital across FD, Savings, Gold, Pension, or any custom type.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _openAddScreen(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Investment'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilteredEmptyState(
    ThemeData theme,
    GlassTokens g,
    InvestmentProvider provider,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        child: GlassContainer(
          borderRadius: AppRadius.lg,
          blur: 0,
          elevated: true,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 52,
                color: g.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text('No matching investments', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Try a different search term or clear your active filter.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _clearFilters(provider),
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: const Text('Clear Filter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvestmentTile extends StatelessWidget {
  final InvestmentModel investment;
  final CurrencyProvider currency;
  final VoidCallback onTapCard;
  final VoidCallback onTapAmount;

  const _InvestmentTile({
    required this.investment,
    required this.currency,
    required this.onTapCard,
    required this.onTapAmount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = context.glass;
    final isDark = theme.brightness == Brightness.dark;
    final color = AppColors.adaptiveColor(investment.displayColor, isDark);
    final amountStr = formatInvestmentAmount(currency, investment.amount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 5),
      child: BouncyTap(
        onPressed: onTapCard,
        child: GlassContainer(
          borderRadius: AppRadius.lg,
          blur: 0,
          elevated: true,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: color.withValues(alpha: isDark ? 0.44 : 0.22),
                  ),
                ),
                child: Icon(
                  InvestmentModel.iconDataFor(investment.icon),
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      investment.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: isDark ? 0.2 : 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            investment.type,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 11,
                          color: g.textSecondary,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            DateFormat('dd MMM yy')
                                .format(investment.investedDate),
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (investment.notes != null &&
                        investment.notes!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        investment.notes!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: g.primarySoft,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onTapAmount,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: g.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          amountStr,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: g.primary,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.calculate_outlined,
                          size: 15,
                          color: g.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
