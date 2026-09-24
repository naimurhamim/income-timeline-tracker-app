import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/entry.dart';
import '../providers/entry_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/blob_painter.dart';
import '../widgets/entry_list_tile.dart';
import '../widgets/summary_cards.dart';
import '../widgets/upcoming_hero_card.dart';
import 'entry_detail_screen.dart';

import 'package:flutter_animate/flutter_animate.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToEntries;

  const DashboardScreen({super.key, this.onNavigateToEntries});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _blobController;

  @override
  void initState() {
    super.initState();
    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _blobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final entryProvider = context.watch<EntryProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => entryProvider.loadAll(),
        color: AppColors.accentLime,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ─── Header with Blobs ───
            SliverPersistentHeader(
              pinned: true,
              delegate: _HeaderDelegate(
                child: _buildHeader(theme, isDark, themeProvider, entryProvider),
                height: MediaQuery.of(context).padding.top + 100,
              ),
            ),

            // ─── Summary Cards ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
                child: SummaryCards(
                  totalUpcoming: entryProvider.thisMonthRemaining,
                  totalReceived: entryProvider.thisMonthReceived,
                  onUpcomingTap: () => widget.onNavigateToEntries?.call(0),
                  onReceivedTap: () => widget.onNavigateToEntries?.call(1),
                ).animate().fade(duration: 500.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),

              ),
            ),

            // ─── Hero Card & Upcoming List ───
            if (entryProvider.upcomingEntries.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: UpcomingHeroCard(
                    entry: entryProvider.upcomingEntries.first,
                    onTap: () => _openDetail(entryProvider.upcomingEntries.first),
                    onMarkReceived: () => _confirmReceived(
                        entryProvider, entryProvider.upcomingEntries.first.id!),
                  ).animate().fade(duration: 500.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), curve: Curves.easeOutBack),

                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Upcoming',
                        style: theme.textTheme.headlineMedium,
                      ),
                      Text(
                        '${entryProvider.upcomingEntries.length - 1} entries',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              if (entryProvider.upcomingEntries.length > 1)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = entryProvider.upcomingEntries[index + 1];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: EntryListTile(
                          entry: entry,
                          onTap: () => _openDetail(entry),
                          onMarkReceived: () =>
                              _confirmReceived(entryProvider, entry.id!),
                        ).animate().fade(delay: (index * 50).ms, duration: 400.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuad),

                      );
                    },
                    childCount: entryProvider.upcomingEntries.length - 1,
                  ),
                ),
            ] else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Text(
                    'Upcoming',
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _buildEmptyState(theme)),
            ],

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark, ThemeProvider themeProvider,
      EntryProvider entryProvider) {
    return AnimatedBuilder(
      animation: _blobController,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppColors.headerGradientDark
                  : AppColors.headerGradient,
            ),
            child: CustomPaint(
              painter: BlobPainter(
                color1: AppColors.accentLime,
                color2: AppColors.accentLavender,
                color3: AppColors.accentLime,
                animationValue: _blobController.value * 2 * pi,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'assets/images/app_icon.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Money Tracker',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Track your income timeline',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => themeProvider.toggleTheme(),
                        icon: Icon(
                          isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.account_balance_wallet_rounded,
              size: 64,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No upcoming entries yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your first entry',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(EntryModel entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntryDetailScreen(entryId: entry.id!),
      ),
    );
  }

  void _confirmReceived(EntryProvider provider, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mark as Received?'),
        content: const Text(
          'This will mark the entry as received. You can undo this later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.markReceived(id);
            },
            child: const Text('Yes, Received'),
          ),
        ],
      ),
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _HeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _HeaderDelegate oldDelegate) {
    return true; // We return true because the content inside relies on providers that might change
  }
}
