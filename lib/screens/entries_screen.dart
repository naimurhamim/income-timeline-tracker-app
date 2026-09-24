import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../providers/entry_provider.dart';
import '../providers/category_provider.dart';
import '../providers/currency_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/entry_list_tile.dart';
import 'add_entry_screen.dart';
import 'entry_detail_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    _tabController = TabController(length: 2, vsync: this);
  }

  void switchToTab(int index) {
    if (index >= 0 && index < 2) {
      _tabController.animateTo(index);
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
    final isDark = theme.brightness == Brightness.dark;
    final entryProvider = context.watch<EntryProvider>();
    final categoryProvider = context.watch<CategoryProvider>();

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 160,
            floating: true,
            pinned: true,
            backgroundColor:
                isDark ? AppColors.primaryTealDark : AppColors.primaryTeal,
            title: _isSearching
                ? _buildSearchField(theme, entryProvider)
                : const Text(
                    'All Entries',
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
                      entryProvider.setSearchQuery(null);
                    }
                  });
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list_rounded,
                    color: Colors.white),
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 50),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!_isSearching) ..._buildStatsRow(entryProvider),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.accentLime,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.schedule_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text('Upcoming (${entryProvider.upcomingEntries.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text(
                          'Received (${entryProvider.receivedEntries.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildEntryList(entryProvider.upcomingEntries, entryProvider, theme),
            _buildEntryList(entryProvider.receivedEntries, entryProvider, theme),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStatsRow(EntryProvider provider) {
    final currency = context.read<CurrencyProvider>();
    return [
      Row(
        children: [
          _statChip('Est. Yearly Amount', currency.compact(provider.getEstimatedYearlyTotal(DateTime.now().year))),
          const SizedBox(width: 24),
          _statChip('Est. Next 3 Months', currency.compact(provider.estimatedNext3MonthsTotal)),
          const SizedBox(width: 24),
          _statChip('Est. Monthly Avg', currency.compact(provider.getEstimatedYearlyTotal(DateTime.now().year) / 12)),
        ],
      ),
    ];
  }

  Widget _statChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(ThemeData theme, EntryProvider entryProvider) {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search entries...',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        border: InputBorder.none,
        filled: false,
      ),
      onChanged: (value) => entryProvider.setSearchQuery(value),
    );
  }

  Widget _buildEntryList(
    List entries,
    EntryProvider provider,
    ThemeData theme,
  ) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 64,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No entries found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
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
    final isDark = theme.brightness == Brightness.dark;
    final badgeColor = isDark ? AppColors.accentLime : AppColors.primaryTeal;

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total ${entries.length} Entries',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    currencyFormat.format(totalAmount),
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ).animate().fade(duration: 300.ms),
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
                    provider.markUnreceived(entry.id!);
                  } else {
                    provider.markReceived(entry.id!);
                  }
                },
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                icon: entry.isReceived
                    ? Icons.undo_rounded
                    : Icons.check_rounded,
                label: entry.isReceived ? 'Undo' : 'Received',
                borderRadius: BorderRadius.circular(12),
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
                borderRadius: BorderRadius.circular(12),
              ),
              SlidableAction(
                onPressed: (_) => _confirmDelete(provider, entry.id!),
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                icon: Icons.delete_rounded,
                label: 'Delete',
                borderRadius: BorderRadius.circular(12),
              ),
            ],
          ),
          child: EntryListTile(
            entry: entry,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EntryDetailScreen(entryId: entry.id!),
              ),
            ),
          ),
        ).animate().fade(delay: (index * 50).ms, duration: 400.ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
      },
    );
  }

  void _confirmDelete(EntryProvider provider, int id) {
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
              provider.deleteEntry(id);
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
