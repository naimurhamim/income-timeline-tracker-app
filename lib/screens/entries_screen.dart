import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/category_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/entry_provider.dart';
import '../theme/app_colors.dart';
import '../theme/glass_tokens.dart';
import '../widgets/entry_list_tile.dart';
import '../widgets/glass_surface.dart';
import 'add_entry_screen.dart';
import 'entry_detail_screen.dart';

class EntriesScreen extends StatefulWidget {
  const EntriesScreen({super.key});

  @override
  State<EntriesScreen> createState() => EntriesScreenState();
}

class EntriesScreenState extends State<EntriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging && mounted) setState(() {});
      });
  }

  void switchToTab(int index) {
    if (index >= 0 && index < 2) {
      _tabController.animateTo(index);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = context.glass;
    final entryProvider = context.watch<EntryProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final currency = context.watch<CurrencyProvider>();
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.railBreakpoint;

    final yearlyEst = entryProvider.getEstimatedYearlyTotal(DateTime.now().year);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
            child: Column(
              children: [
                // ─── Top Header ───
                Padding(
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
                                    hintText: 'Search entries...',
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: entryProvider.setSearchQuery,
                                ),
                              )
                            : Text(
                                'All Entries',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      GlassCircleButton(
                        icon: _isSearching
                            ? Icons.close_rounded
                            : Icons.search_rounded,
                        tooltip: _isSearching ? 'Close search' : 'Search entries',
                        size: 42,
                        onTap: () {
                          setState(() {
                            _isSearching = !_isSearching;
                            if (!_isSearching) {
                              _searchController.clear();
                              entryProvider.setSearchQuery(null);
                            }
                          });
                        },
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      PopupMenuButton<String>(
                        tooltip: 'Filter by type',
                        onSelected: (value) {
                          if (value == 'all') {
                            entryProvider.setFilterType(null);
                          } else {
                            entryProvider.setFilterType(value);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'all',
                            child: Text('All Types'),
                          ),
                          ...categoryProvider.categories.map(
                            (cat) => PopupMenuItem(
                              value: cat.name,
                              child: Text(cat.name),
                            ),
                          ),
                        ],
                        child: GlassContainer(
                          borderRadius: AppRadius.pill,
                          blur: 0,
                          elevated: true,
                          borderColor: entryProvider.filterType != null
                              ? g.primary
                              : g.glassBorder,
                          child: SizedBox(
                            width: 42,
                            height: 42,
                            child: Icon(
                              Icons.filter_list_rounded,
                              size: AppIconSize.md,
                              color: entryProvider.filterType != null
                                  ? g.primary
                                  : g.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Compact Stats Glass Strip ───
                if (!_isSearching)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: GlassContainer(
                      borderRadius: AppRadius.lg,
                      blur: 0,
                      elevated: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatBox(
                              label: 'Est. Yearly',
                              value: currency.compact(yearlyEst),
                            ),
                          ),
                          Container(width: 1, height: 28, color: g.border),
                          Expanded(
                            child: _StatBox(
                              label: 'Next 3 Months',
                              value: currency.compact(
                                  entryProvider.estimatedNext3MonthsTotal),
                            ),
                          ),
                          Container(width: 1, height: 28, color: g.border),
                          Expanded(
                            child: _StatBox(
                              label: 'Monthly Avg',
                              value: currency.compact(yearlyEst / 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ─── Segmented Frosted Tabs ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: GlassContainer(
                    borderRadius: AppRadius.pill,
                    blur: 0,
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SegmentButton(
                            label:
                                'Upcoming (${entryProvider.upcomingEntries.length})',
                            icon: Icons.schedule_rounded,
                            selected: _tabController.index == 0,
                            onTap: () => switchToTab(0),
                          ),
                        ),
                        Expanded(
                          child: _SegmentButton(
                            label:
                                'Received (${entryProvider.receivedEntries.length})',
                            icon: Icons.check_circle_rounded,
                            selected: _tabController.index == 1,
                            onTap: () => switchToTab(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // ─── Tab View ───
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildEntryList(
                        entryProvider.upcomingEntries,
                        entryProvider,
                        theme,
                        wide: wide,
                      ),
                      _buildEntryList(
                        entryProvider.receivedEntries,
                        entryProvider,
                        theme,
                        wide: wide,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryList(
    List entries,
    EntryProvider provider,
    ThemeData theme, {
    required bool wide,
  }) {
    final g = context.glass;
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: GlassContainer(
            borderRadius: AppRadius.lg,
            blur: 0,
            elevated: true,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inbox_rounded,
                  size: 48,
                  color: g.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'No entries found',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: g.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currency = context.read<CurrencyProvider>();
    final currencyFormat = NumberFormat.currency(
      locale: currency.locale,
      symbol: currency.symbol,
      decimalDigits: 0,
    );
    final totalAmount = entries.fold(0.0, (sum, e) => sum + e.amount);

    return ListView.builder(
      padding: EdgeInsets.only(
        top: 4,
        bottom: wide ? AppSpacing.xl : AppLayout.navClearance + 28,
      ),
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total ${entries.length} ${entries.length == 1 ? 'Entry' : 'Entries'}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: g.textSecondary,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: g.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: g.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    currencyFormat.format(totalAmount),
                    style: TextStyle(
                      color: g.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ).animate().fade(duration: 280.ms),
          );
        }

        final entry = entries[index - 1];
        return Slidable(
          key: ValueKey(entry.id),
          startActionPane: ActionPane(
            motion: const BehindMotion(),
            children: [
              SlidableAction(
                onPressed: (_) {
                  if (entry.isReceived) {
                    provider.markUnreceived(entry.id);
                  } else {
                    provider.markReceived(entry.id);
                  }
                },
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                icon: entry.isReceived
                    ? Icons.undo_rounded
                    : Icons.check_rounded,
                label: entry.isReceived ? 'Undo' : 'Received',
                borderRadius: BorderRadius.circular(14),
              ),
            ],
          ),
          endActionPane: ActionPane(
            motion: const BehindMotion(),
            children: [
              SlidableAction(
                onPressed: (_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEntryScreen(editEntry: entry),
                    ),
                  );
                },
                backgroundColor: AppColors.info,
                foregroundColor: Colors.white,
                icon: Icons.edit_rounded,
                label: 'Edit',
                borderRadius: BorderRadius.circular(14),
              ),
              SlidableAction(
                onPressed: (_) => _confirmDelete(provider, entry.id),
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                icon: Icons.delete_rounded,
                label: 'Delete',
                borderRadius: BorderRadius.circular(14),
              ),
            ],
          ),
          child: EntryListTile(
            entry: entry,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EntryDetailScreen(entryId: entry.id),
              ),
            ),
            onMarkReceived: () {
              if (!entry.isReceived) provider.markReceived(entry.id);
            },
          ),
        );
      },
    );
  }

  void _confirmDelete(EntryProvider provider, String id) {
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
              provider.deleteEntry(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = context.glass;
    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(color: g.textSecondary),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: g.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          color: selected ? g.glassFillElevated : Colors.transparent,
          border: selected ? Border.all(color: g.glassBorder) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? g.primary : g.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? g.textPrimary : g.textSecondary,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
