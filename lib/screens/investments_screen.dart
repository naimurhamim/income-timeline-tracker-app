import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/investment.dart';
import '../providers/currency_provider.dart';
import '../providers/investment_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/bouncy_tap.dart';
import '../widgets/calculator_keyboard.dart';
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
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<InvestmentProvider>();
    final currency = context.watch<CurrencyProvider>();

    final all = provider.allInvestments;
    final filtered = provider.filteredInvestments;
    final totalsByType = provider.totalsByType;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => provider.loadInvestments(preferServer: true),
        color: AppColors.accentLime,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ─── Header AppBar ───
            SliverAppBar(
              expandedHeight: 110,
              floating: true,
              pinned: true,
              backgroundColor:
                  isDark ? AppColors.primaryTealDark : AppColors.primaryTeal,
              title: _isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search investments...',
                        hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6)),
                        border: InputBorder.none,
                        filled: false,
                      ),
                      onChanged: provider.setSearchQuery,
                    )
                  : const Text(
                      'Investments',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
              actions: [
                IconButton(
                  icon: Icon(
                    _isSearching ? Icons.close_rounded : Icons.search_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchController.clear();
                        provider.setSearchQuery('');
                      }
                    });
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? AppColors.headerGradientDark
                        : AppColors.headerGradient,
                  ),
                ),
              ),
            ),

            // ─── Hero Summary Card ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: _buildHeroCard(
                  theme: theme,
                  isDark: isDark,
                  provider: provider,
                  currency: currency,
                  typeCount: totalsByType.length,
                ).animate().fade(duration: 400.ms).slideY(
                      begin: 0.08,
                      end: 0,
                      curve: Curves.easeOutQuad,
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

            // ─── Content: Empty / Filtered Empty / List ───
            if (all.isEmpty && !provider.isLoading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(theme, isDark),
              )
            else if (filtered.isEmpty && !provider.isLoading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildFilteredEmptyState(theme, provider),
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          SlidableAction(
                            onPressed: (_) => _confirmDelete(
                                context, inv, provider, currency),
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            icon: Icons.delete_rounded,
                            label: 'Delete',
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ],
                      ),
                      child: _InvestmentTile(
                        investment: inv,
                        currency: currency,
                        onTapCard: () => _openAddScreen(edit: inv),
                        onTapAmount: () =>
                            _quickEditAmount(context, inv, provider, currency),
                      ),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient:
            isDark ? AppColors.headerGradientDark : AppColors.headerGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryTeal.withValues(alpha: 0.25),
            blurRadius: 18,
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
              const Text(
                'Total Invested',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.accentLime,
                      size: 14,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Principal Capital',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '$totalCount ${totalCount == 1 ? 'record' : 'records'} · $typeCount ${typeCount == 1 ? 'type' : 'types'}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (hasFilter) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentLime.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${provider.selectedTypeFilter ?? 'Search'}: ${formatInvestmentAmount(currency, provider.filteredTotal)}',
                    style: const TextStyle(
                      color: AppColors.accentLime,
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

  Widget _buildTypeFilterBar({
    required ThemeData theme,
    required bool isDark,
    required InvestmentProvider provider,
    required CurrencyProvider currency,
    required Map<String, double> totalsByType,
  }) {
    final total = provider.totalInvested;
    final presetsByKey = {
      for (final p in provider.allAvailableTypePresets)
        p.name.trim().toLowerCase(): p,
    };

    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _buildFilterChip(
            theme: theme,
            isDark: isDark,
            label: 'All (${provider.allInvestments.length})',
            icon: Icons.apps_rounded,
            color: isDark ? AppColors.accentLime : AppColors.primaryTeal,
            isSelected: provider.selectedTypeFilter == null,
            onTap: () => provider.setTypeFilter(null),
          ),
          const SizedBox(width: 8),
          ...totalsByType.entries.map((entry) {
            final typeName = entry.key;
            final typeAmount = entry.value;
            final pct =
                total > 0 ? ((typeAmount / total) * 100).round() : 0;
            final preset = presetsByKey[typeName.trim().toLowerCase()];
            final color = preset?.displayColor ?? AppColors.primaryTeal;
            final icon = InvestmentModel.iconDataFor(preset?.icon ?? 'wallet');
            final isSelected = provider.selectedTypeFilter?.toLowerCase() ==
                typeName.trim().toLowerCase();

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFilterChip(
                theme: theme,
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
    required bool isDark,
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.24 : 0.14)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? color
                : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? color : theme.textTheme.bodySmall?.color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: (isDark ? AppColors.accentLime : AppColors.primaryTeal)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 42,
                color: isDark ? AppColors.accentLime : AppColors.primaryTeal,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Investments Yet',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Track your principal capital across FD, Savings, Gold, Pension, or any custom type.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: () => _openAddScreen(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Investment'),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredEmptyState(
    ThemeData theme,
    InvestmentProvider provider,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 58,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No matching investments',
              style: theme.textTheme.titleLarge,
            ),
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
            const SizedBox(height: 60),
          ],
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
    final isDark = theme.brightness == Brightness.dark;
    final color = investment.displayColor;
    final amountStr = formatInvestmentAmount(currency, investment.amount);

    return BouncyTap(
      onPressed: onTapCard,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
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
            // Icon container
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                InvestmentModel.iconDataFor(investment.icon),
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Title, Type pill, Date, Notes
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
                          color: color.withValues(alpha: 0.14),
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
                        color: theme.textTheme.bodySmall?.color,
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

            // Tappable Amount Pill -> opens Calculator directly
            Material(
              color: (isDark ? AppColors.accentLime : AppColors.primaryTeal)
                  .withValues(alpha: 0.1),
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
                      color: (isDark
                              ? AppColors.accentLime
                              : AppColors.primaryTeal)
                          .withValues(alpha: 0.25),
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
                          color: isDark
                              ? AppColors.accentLime
                              : AppColors.primaryTeal,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        Icons.calculate_outlined,
                        size: 15,
                        color: isDark
                            ? AppColors.accentLime
                            : AppColors.primaryTeal,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
