import 'package:flutter/material.dart';
import '../screens/dashboard_screen.dart';
import '../screens/entries_screen.dart';
import '../screens/summary_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/add_entry_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/slide_indexed_stack.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  final GlobalKey<EntriesScreenState> _entriesKey = GlobalKey<EntriesScreenState>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SlideIndexedStack(
        index: _currentIndex,
        duration: const Duration(milliseconds: 300),
        children: [
          DashboardScreen(
            onNavigateToEntries: (int tabIndex) {
              setState(() => _currentIndex = 1);
              // Switch to the correct tab in EntriesScreen
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _entriesKey.currentState?.switchToTab(tabIndex);
              });
            },
          ),
          EntriesScreen(key: _entriesKey),
          const SummaryScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            indicatorColor: isDark
                ? AppColors.accentLime.withValues(alpha: 0.2)
                : AppColors.primaryTeal.withValues(alpha: 0.1),
            height: 72,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: Icon(
                  Icons.dashboard_rounded,
                  color: _currentIndex == 0
                      ? (isDark ? AppColors.accentLime : AppColors.primaryTeal)
                      : theme.textTheme.bodySmall?.color,
                ),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.list_alt_rounded,
                  color: _currentIndex == 1
                      ? (isDark ? AppColors.accentLime : AppColors.primaryTeal)
                      : theme.textTheme.bodySmall?.color,
                ),
                label: 'Entries',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.bar_chart_rounded,
                  color: _currentIndex == 2
                      ? (isDark ? AppColors.accentLime : AppColors.primaryTeal)
                      : theme.textTheme.bodySmall?.color,
                ),
                label: 'Summary',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.settings_rounded,
                  color: _currentIndex == 3
                      ? (isDark ? AppColors.accentLime : AppColors.primaryTeal)
                      : theme.textTheme.bodySmall?.color,
                ),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _currentIndex <= 1
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddEntryScreen(),
                  ),
                );
              },
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
    );
  }
}
