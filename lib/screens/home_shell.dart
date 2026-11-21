import 'dart:ui';
import 'package:flutter/material.dart';
import '../screens/dashboard_screen.dart';
import '../screens/entries_screen.dart';
import '../screens/investments_screen.dart';
import '../screens/summary_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/add_entry_screen.dart';
import '../screens/add_investment_screen.dart';
import '../theme/app_colors.dart';
import '../theme/glass_tokens.dart';
import '../widgets/glass_surface.dart';
import '../widgets/slide_indexed_stack.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  final GlobalKey<EntriesScreenState> _entriesKey =
      GlobalKey<EntriesScreenState>();

  void _selectTab(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  void _openAddAction() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _currentIndex == 2
            ? const AddInvestmentScreen()
            : const AddEntryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.railBreakpoint;

    final stack = SlideIndexedStack(
      index: _currentIndex,
      duration: const Duration(milliseconds: 280),
      children: [
        DashboardScreen(
          onNavigateToEntries: (int tabIndex) {
            setState(() => _currentIndex = 1);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _entriesKey.currentState?.switchToTab(tabIndex);
            });
          },
          onNavigateToInvest: () => _selectTab(2),
          onNavigateToSettings: () => _selectTab(4),
        ),
        EntriesScreen(key: _entriesKey),
        const InvestmentsScreen(),
        const SummaryScreen(),
        const SettingsScreen(),
      ],
    );

    if (wide) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: GlassBackdrop(
          child: Row(
            children: [
              GlassContainer(
                borderRadius: 0,
                blur: 14,
                child: NavigationRail(
                  backgroundColor: Colors.transparent,
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _selectTab,
                  labelType: NavigationRailLabelType.all,
                  indicatorColor: g.primarySoft,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard_rounded),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.list_alt_outlined),
                      selectedIcon: Icon(Icons.list_alt_rounded),
                      label: Text('Entries'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                      label: Text('Invest'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.bar_chart_outlined),
                      selectedIcon: Icon(Icons.bar_chart_rounded),
                      label: Text('Summary'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(Icons.person_rounded),
                      label: Text('Settings'),
                    ),
                  ],
                ),
              ),
              Expanded(child: stack),
            ],
          ),
        ),
        floatingActionButton: _currentIndex <= 2
            ? FloatingActionButton(
                onPressed: _openAddAction,
                child: const Icon(Icons.add_rounded, size: 28),
              )
            : null,
      );
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Stack(
          children: [
            Positioned.fill(child: stack),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Row(
                        children: [
                          Expanded(
                            child: _FloatingGlassNav(
                              selectedIndex: _currentIndex,
                              onSelect: _selectTab,
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            child: _currentIndex <= 2
                                ? Padding(
                                    padding: const EdgeInsets.only(
                                      left: AppSpacing.sm,
                                    ),
                                    child: _InlineAddActionButton(
                                      tooltip: _currentIndex == 2
                                          ? 'Add Investment'
                                          : 'Add Entry',
                                      onTap: _openAddAction,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
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

class _InlineAddActionButton extends StatelessWidget {
  const _InlineAddActionButton({
    required this.tooltip,
    required this.onTap,
  });

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark ? AppColors.accentMintLight : g.surface;
    final fg = dark ? const Color(0xFF06160C) : g.primary;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.28)
                    : g.primary.withValues(alpha: 0.24),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: dark
                      ? AppColors.accentMintLight.withValues(alpha: 0.28)
                      : g.glassShadow,
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(Icons.add_rounded, color: fg, size: 28),
          ),
        ),
      ),
    );
  }
}

class _FloatingGlassNav extends StatelessWidget {
  const _FloatingGlassNav({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: g.navDockFill,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: g.navDockBorder, width: 1.1),
            boxShadow: [
              BoxShadow(
                color: g.glassShadow,
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavOrbButton(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                tooltip: 'Dashboard',
                selected: selectedIndex == 0,
                onTap: () => onSelect(0),
              ),
              _NavOrbButton(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                tooltip: 'Entries',
                selected: selectedIndex == 1,
                onTap: () => onSelect(1),
              ),
              _NavOrbButton(
                icon: Icons.account_balance_wallet_outlined,
                activeIcon: Icons.account_balance_wallet_rounded,
                tooltip: 'Invest',
                selected: selectedIndex == 2,
                onTap: () => onSelect(2),
              ),
              _NavOrbButton(
                icon: Icons.bar_chart_outlined,
                activeIcon: Icons.bar_chart_rounded,
                tooltip: 'Summary',
                selected: selectedIndex == 3,
                onTap: () => onSelect(3),
              ),
              _NavOrbButton(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                tooltip: 'Settings',
                selected: selectedIndex == 4,
                onTap: () => onSelect(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavOrbButton extends StatelessWidget {
  const _NavOrbButton({
    required this.icon,
    required this.activeIcon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Semantics(
      label: tooltip,
      button: true,
      selected: selected,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? g.navIconActiveBg : Colors.transparent,
            ),
            child: Icon(
              selected ? activeIcon : icon,
              size: 22,
              color: selected ? g.navIconActiveFg : g.navIconInactive,
            ),
          ),
        ),
      ),
    );
  }
}
