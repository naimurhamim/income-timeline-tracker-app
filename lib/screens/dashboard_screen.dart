import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/entry.dart';
import '../providers/entry_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/notification_provider.dart';
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
    final notifProvider = context.watch<NotificationProvider>();

    // Regenerate in-app notifications whenever entries change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifProvider.generateFromEntries(entryProvider.upcomingEntries);
    });

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
                child: _buildHeader(theme, isDark, themeProvider, entryProvider, notifProvider),
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
      EntryProvider entryProvider, NotificationProvider notifProvider) {
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => themeProvider.toggleTheme(),
                            icon: Icon(
                              isDark
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                              color: Colors.white,
                            ),
                          ),
                          _NotificationBell(
                            notifProvider: notifProvider,
                            isDark: isDark,
                          ),
                        ],
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

// ═══════════════════════════════════════════════════════
//  Notification Bell + Glassmorphism Popup
// ═══════════════════════════════════════════════════════

class _NotificationBell extends StatefulWidget {
  final NotificationProvider notifProvider;
  final bool isDark;

  const _NotificationBell({
    required this.notifProvider,
    required this.isDark,
  });

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  final _bellKey = GlobalKey();
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void didUpdateWidget(covariant _NotificationBell old) {
    super.didUpdateWidget(old);
    if (widget.notifProvider.unseenCount > 0 &&
        !_shakeController.isAnimating) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _shakeController.dispose();
    super.dispose();
  }

  void _togglePopup() {
    if (_overlayEntry != null) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay() {
    final renderBox =
        _bellKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (_) => _NotificationPopup(
        anchorX: offset.dx + size.width / 2,
        anchorY: offset.dy + size.height + 4,
        isDark: widget.isDark,
        notifProvider: widget.notifProvider,
        onDismiss: _removeOverlay,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.notifProvider.unseenCount;

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final angle = sin(_shakeController.value * pi * 4) * 0.15;
        return Transform.rotate(angle: angle, child: child);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            key: _bellKey,
            onPressed: _togglePopup,
            icon: Icon(
              count > 0
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              color: Colors.white,
            ),
          ),
          if (count > 0)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.error.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  Glassmorphism Notification Popup
// ═══════════════════════════════════════════════════════

class _NotificationPopup extends StatelessWidget {
  final double anchorX;
  final double anchorY;
  final bool isDark;
  final NotificationProvider notifProvider;
  final VoidCallback onDismiss;

  const _NotificationPopup({
    required this.anchorX,
    required this.anchorY,
    required this.isDark,
    required this.notifProvider,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final popupWidth = screenWidth - 32.0;
    // Position popup centered horizontally or aligned to right
    final left = (screenWidth - popupWidth) / 2;

    return Stack(
      children: [
        // Dismiss area
        GestureDetector(
          onTap: onDismiss,
          behavior: HitTestBehavior.opaque,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: left,
          top: anchorY,
          width: popupWidth,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 380),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_rounded,
                              size: 18,
                              color: isDark
                                  ? AppColors.accentLime
                                  : AppColors.primaryTeal,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Notifications',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.primaryTealDark,
                              ),
                            ),
                            const Spacer(),
                            if (notifProvider.unseenCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.accentLime.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${notifProvider.unseenCount} new',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.accentLime
                                        : AppColors.primaryTeal,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                      // Body
                      if (notifProvider.items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.notifications_off_rounded,
                                size: 36,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.black26,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'All clear! No upcoming reminders.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            itemCount: notifProvider.items.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, i) {
                              final item = notifProvider.items[i];
                              final isRead = notifProvider.isRead(item);
                              return _NotificationTile(
                                item: item,
                                isRead: isRead,
                                isDark: isDark,
                              );
                            },
                          ),
                        ),
                      // Footer — Mark all read
                      if (notifProvider.unseenCount > 0) ...[
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                        InkWell(
                          onTap: () {
                            notifProvider.markAllRead();
                            onDismiss();
                          },
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                'Mark all as read',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.accentLime
                                      : AppColors.primaryTeal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final bool isRead;
  final bool isDark;

  const _NotificationTile({
    required this.item,
    required this.isRead,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = _typeColor(item.type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isRead
            ? Colors.transparent
            : (isDark
                ? accentColor.withValues(alpha: 0.08)
                : accentColor.withValues(alpha: 0.06)),
        borderRadius: BorderRadius.circular(12),
        border: isRead
            ? null
            : Border.all(
                color: accentColor.withValues(alpha: isDark ? 0.2 : 0.15)),
      ),
      child: Row(
        children: [
          Icon(item.icon, size: 22, color: accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.primaryTealDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.body,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (!isRead)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor,
              ),
            ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'overdue':
        return AppColors.error;
      case 'today':
        return AppColors.success;
      case '3day':
        return AppColors.warning;
      case '7day':
        return AppColors.info;
      default:
        return AppColors.primaryTeal;
    }
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
