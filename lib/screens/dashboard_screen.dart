import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/entry.dart';
import '../providers/account_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/entry_provider.dart';
import '../providers/investment_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../theme/glass_tokens.dart';
import '../widgets/entry_list_tile.dart';
import '../widgets/finance_charts.dart';
import '../widgets/glass_surface.dart';
import '../widgets/upcoming_hero_card.dart';
import 'add_entry_screen.dart';
import 'add_investment_screen.dart';
import 'entry_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToEntries;
  final VoidCallback? onNavigateToInvest;
  final VoidCallback? onNavigateToSettings;

  const DashboardScreen({
    super.key,
    this.onNavigateToEntries,
    this.onNavigateToInvest,
    this.onNavigateToSettings,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _upcomingTypeFilter;

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning!';
    if (hour < 17) return 'Good afternoon!';
    return 'Good evening!';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = context.glass;
    final isDark = theme.brightness == Brightness.dark;
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.railBreakpoint;

    final entryProvider = context.watch<EntryProvider>();
    final investmentProvider = context.watch<InvestmentProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final notifProvider = context.watch<NotificationProvider>();
    final accountProvider = context.watch<AccountProvider>();
    final currency = context.watch<CurrencyProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifProvider.generateFromEntries(entryProvider.upcomingEntries);
    });

    final displayName = accountProvider.isSignedIn &&
            accountProvider.displayName.trim().isNotEmpty
        ? accountProvider.displayName.trim()
        : 'Money Tracker';

    final upcomingAll = entryProvider.upcomingEntries;
    final upcomingTypes = <String>{
      for (final e in upcomingAll)
        if (e.type.trim().isNotEmpty) e.type.trim(),
    }.toList();

    final effectiveFilter =
        _upcomingTypeFilter != null && upcomingTypes.contains(_upcomingTypeFilter)
            ? _upcomingTypeFilter
            : null;

    final filteredUpcomingList = effectiveFilter == null
        ? (upcomingAll.length > 1 ? upcomingAll.sublist(1) : <EntryModel>[])
        : upcomingAll
            .where((e) => e.type.trim() == effectiveFilter)
            .toList();

    final monthRemaining = entryProvider.thisMonthRemaining;
    final monthReceived = entryProvider.thisMonthReceived;
    final monthTotal = monthRemaining + monthReceived;
    final monthProgress =
        monthTotal > 0 ? (monthReceived / monthTotal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
            child: RefreshIndicator(
              onRefresh: () async {
                await entryProvider.loadAll();
                await investmentProvider.loadInvestments();
              },
              color: g.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ─── Top Greeting Bar ───
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _greetingText(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: g.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GlassCircleButton(
                            icon: isDark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                            tooltip: isDark
                                ? 'Switch to Light theme'
                                : 'Switch to Dark theme',
                            size: 40,
                            onTap: () => themeProvider.toggleTheme(
                              currentBrightness: theme.brightness,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _NotificationBell(
                            notifProvider: notifProvider,
                            isDark: isDark,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _UserAvatarButton(
                            photoUrl: accountProvider.photoUrl,
                            name: accountProvider.isSignedIn
                                ? accountProvider.displayName
                                : null,
                            onTap: () => widget.onNavigateToSettings?.call(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─── One-time Migration Banner ───
                  if (accountProvider.migrationNotice != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.md,
                        ),
                        child: GlassContainer(
                          borderRadius: AppRadius.md,
                          blur: 0,
                          elevated: true,
                          borderColor: g.primary.withValues(alpha: 0.45),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Icon(Icons.verified_user_rounded,
                                  color: g.primary, size: 20),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  accountProvider.migrationNotice!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: g.textPrimary,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                visualDensity: VisualDensity.compact,
                                onPressed:
                                    accountProvider.dismissMigrationNotice,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ─── Luminous Hero Capital + Month Summary Card ───
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: _DashboardHeroCard(
                        isDark: isDark,
                        totalInvestedLabel: formatInvestmentAmount(
                          currency,
                          investmentProvider.totalInvested,
                        ),
                        investmentCount:
                            investmentProvider.allInvestments.length,
                        thisMonthRemainingLabel: formatInvestmentAmount(
                          currency,
                          monthRemaining,
                        ),
                        thisMonthReceivedLabel: formatInvestmentAmount(
                          currency,
                          monthReceived,
                        ),
                        onInvestTap: widget.onNavigateToInvest,
                        onUpcomingTap: () =>
                            widget.onNavigateToEntries?.call(0),
                        onReceivedTap: () =>
                            widget.onNavigateToEntries?.call(1),
                      )
                          .animate()
                          .fade(duration: 420.ms)
                          .slideY(
                            begin: 0.06,
                            end: 0,
                            curve: Curves.easeOutQuad,
                          ),
                    ),
                  ),

                  // ─── Monthly Collection Gauge Card ───
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: GlassContainer(
                        borderRadius: AppRadius.xl,
                        blur: 0,
                        elevated: true,
                        onTap: () => widget.onNavigateToEntries?.call(0),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Row(
                          children: [
                            CircularFinanceRing(
                              progress: monthProgress,
                              centerValue: '${(monthProgress * 100).round()}%',
                              centerLabel: 'Collected',
                              size: 92,
                              strokeWidth: 9,
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Monthly Cashflow',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    monthTotal > 0
                                        ? '${formatInvestmentAmount(currency, monthReceived)} collected of ${formatInvestmentAmount(currency, monthTotal)} expected this month'
                                        : 'No payouts scheduled for this month yet.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: g.textSecondary,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: g.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ─── Next Upcoming Hero & Filtered List ───
                  if (upcomingAll.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: UpcomingHeroCard(
                          entry: upcomingAll.first,
                          onTap: () => _openDetail(upcomingAll.first),
                          onMarkReceived: () => _confirmReceived(
                            entryProvider,
                            upcomingAll.first.id,
                          ),
                        )
                            .animate()
                            .fade(duration: 450.ms)
                            .scale(
                              begin: const Offset(0.97, 0.97),
                              end: const Offset(1, 1),
                              curve: Curves.easeOutBack,
                            ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          20,
                          AppSpacing.lg,
                          10,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Upcoming',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${upcomingAll.length})',
                              style: theme.textTheme.bodySmall,
                            ),
                            const Spacer(),
                            InkWell(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              onTap: () => widget.onNavigateToEntries?.call(0),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'See all',
                                      style:
                                          theme.textTheme.labelLarge?.copyWith(
                                        color: g.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 15,
                                      color: g.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (upcomingTypes.length > 1)
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 44,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GlassPillButton(
                                  label: 'All',
                                  selected: effectiveFilter == null,
                                  onTap: () => setState(
                                      () => _upcomingTypeFilter = null),
                                ),
                              ),
                              ...upcomingTypes.map((type) {
                                final isSelected = effectiveFilter == type;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GlassPillButton(
                                    label: type,
                                    selected: isSelected,
                                    onTap: () => setState(() {
                                      _upcomingTypeFilter =
                                          isSelected ? null : type;
                                    }),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    if (upcomingTypes.length > 1)
                      const SliverToBoxAdapter(child: SizedBox(height: 6)),
                    if (filteredUpcomingList.isNotEmpty)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final entry = filteredUpcomingList[index];
                            return EntryListTile(
                              entry: entry,
                              onTap: () => _openDetail(entry),
                              onMarkReceived: () =>
                                  _confirmReceived(entryProvider, entry.id),
                            )
                                .animate()
                                .fade(
                                  delay: (index.clamp(0, 8) * 40).ms,
                                  duration: 320.ms,
                                )
                                .slideY(
                                  begin: 0.12,
                                  end: 0,
                                  curve: Curves.easeOutQuad,
                                );
                          },
                          childCount: filteredUpcomingList.length,
                        ),
                      ),
                  ] else
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: _buildEmptyState(context, theme),
                      ),
                    ),

                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: wide ? AppSpacing.xl : AppLayout.navClearance + 28,
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

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    final g = context.glass;
    return GlassContainer(
      borderRadius: AppRadius.lg,
      blur: 0,
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: g.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_available_rounded,
              size: 32,
              color: g.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No upcoming entries yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + to schedule your upcoming FD maturity, savings payout, or income.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          GlassPillButton(
            icon: Icons.add_rounded,
            label: 'Add Entry',
            selected: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEntryScreen()),
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(EntryModel entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntryDetailScreen(entryId: entry.id),
      ),
    );
  }

  void _confirmReceived(EntryProvider provider, String id) {
    final g = context.glass;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: g.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: g.glassBorder),
        ),
        title: const Text('Mark as Received?'),
        content: const Text(
          'This will mark the entry as received. You can undo this later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
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

class _DashboardHeroCard extends StatelessWidget {
  const _DashboardHeroCard({
    required this.isDark,
    required this.totalInvestedLabel,
    required this.investmentCount,
    required this.thisMonthRemainingLabel,
    required this.thisMonthReceivedLabel,
    this.onInvestTap,
    this.onUpcomingTap,
    this.onReceivedTap,
  });

  final bool isDark;
  final String totalInvestedLabel;
  final int investmentCount;
  final String thisMonthRemainingLabel;
  final String thisMonthReceivedLabel;
  final VoidCallback? onInvestTap;
  final VoidCallback? onUpcomingTap;
  final VoidCallback? onReceivedTap;

  @override
  Widget build(BuildContext context) {
    final heroFg = isDark ? const Color(0xFF06160C) : Colors.white;
    final subLabelFg =
        isDark ? const Color(0xCC06160C) : Colors.white.withValues(alpha: 0.8);
    final pillBg = isDark
        ? const Color(0xFF06160C).withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.16);

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.darkMintHeroGradient
            : AppColors.lightForestHeroGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.accentMintLight : AppColors.deepForest)
                .withValues(alpha: isDark ? 0.24 : 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onInvestTap,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Principal Balance',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: subLabelFg,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$investmentCount assets',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: heroFg,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 14,
                                color: heroFg,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        totalInvestedLabel,
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(
                              color: heroFg,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.1,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroInnerMetricCard(
                  isDarkHero: isDark,
                  icon: Icons.south_west_rounded,
                  iconBgColor: AppColors.accentMintLight,
                  label: 'This Month',
                  value: thisMonthRemainingLabel,
                  onTap: onUpcomingTap,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _HeroInnerMetricCard(
                  isDarkHero: isDark,
                  icon: Icons.check_rounded,
                  iconBgColor: const Color(0xFF6EF094),
                  label: 'Received',
                  value: thisMonthReceivedLabel,
                  onTap: onReceivedTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroInnerMetricCard extends StatelessWidget {
  const _HeroInnerMetricCard({
    required this.isDarkHero,
    required this.icon,
    required this.iconBgColor,
    required this.label,
    required this.value,
    this.onTap,
  });

  final bool isDarkHero;
  final IconData icon;
  final Color iconBgColor;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isDarkHero ? AppColors.obsidianCardDark : const Color(0xFF0E3422);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBgColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 15, color: iconBgColor),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 10.5,
                          ),
                    ),
                    const SizedBox(height: 1),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserAvatarButton extends StatelessWidget {
  const _UserAvatarButton({
    required this.photoUrl,
    required this.name,
    required this.onTap,
  });

  final String? photoUrl;
  final String? name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    final initial = (name != null && name!.trim().isNotEmpty)
        ? name!.trim().substring(0, 1).toUpperCase()
        : null;

    return Semantics(
      label: 'Open Settings',
      button: true,
      child: GlassContainer(
        borderRadius: AppRadius.pill,
        blur: 0,
        elevated: true,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: hasPhoto
              ? ClipOval(
                  child: Image.network(
                    photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const AppLogoMark(size: 44),
                  ),
                )
              : (initial != null
                  ? Center(
                      child: Text(
                        initial,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: g.textPrimary,
                            ),
                      ),
                    )
                  : const AppLogoMark(size: 44)),
        ),
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
    if (widget.notifProvider.unseenCount > 0 && !_shakeController.isAnimating) {
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
        anchorY: offset.dy + size.height + 6,
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
        final angle = sin(_shakeController.value * pi * 4) * 0.14;
        return Transform.rotate(angle: angle, child: child);
      },
      child: KeyedSubtree(
        key: _bellKey,
        child: GlassCircleButton(
          icon: count > 0
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          badgeCount: count,
          size: 42,
          onTap: _togglePopup,
        ),
      ),
    );
  }
}

class _NotificationPopup extends StatelessWidget {
  final double anchorY;
  final bool isDark;
  final NotificationProvider notifProvider;
  final VoidCallback onDismiss;

  const _NotificationPopup({
    required this.anchorY,
    required this.isDark,
    required this.notifProvider,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final popupWidth = min(screenWidth - 32.0, 480.0);
    final left = (screenWidth - popupWidth) / 2;
    final g = context.glass;

    return Stack(
      children: [
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
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 380),
                  decoration: BoxDecoration(
                    color: g.glassFillElevated,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: g.glassBorder),
                    boxShadow: [
                      BoxShadow(
                        color: g.glassShadow,
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_rounded,
                              size: 18,
                              color: g.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Notifications',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: g.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            if (notifProvider.unseenCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: g.primarySoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${notifProvider.unseenCount} new',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: g.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: g.border),
                      if (notifProvider.items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.notifications_off_rounded,
                                size: 36,
                                color: g.textSecondary.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'All clear! No upcoming reminders.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: g.textSecondary,
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
                            separatorBuilder: (_, _) =>
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
                      if (notifProvider.unseenCount > 0) ...[
                        Divider(height: 1, color: g.border),
                        InkWell(
                          onTap: () {
                            notifProvider.markAllRead();
                            onDismiss();
                          },
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(22),
                            bottomRight: Radius.circular(22),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                'Mark all as read',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: g.primary,
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
    final g = context.glass;
    final accentColor = _typeColor(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isRead
            ? Colors.transparent
            : accentColor.withValues(alpha: isDark ? 0.1 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: isRead
            ? null
            : Border.all(
                color: accentColor.withValues(alpha: isDark ? 0.28 : 0.18),
              ),
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
                    color: g.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.body,
                  style: TextStyle(
                    fontSize: 12,
                    color: g.textSecondary,
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

  Color _typeColor(bool isDark) {
    switch (item.type) {
      case 'overdue':
        return AppColors.error;
      case 'today':
        return AppColors.success;
      case '3day':
        return AppColors.warning;
      case '7day':
        return AppColors.info;
      default:
        return AppColors.adaptiveColor(AppColors.primaryTeal, isDark);
    }
  }
}
