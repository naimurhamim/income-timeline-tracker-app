import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/currency_provider.dart';
import '../services/auth_service.dart';
import '../services/update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_colors.dart';
import 'pin_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final authService = context.watch<AuthService>();
    final currencyProvider = context.watch<CurrencyProvider>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor:
                isDark ? AppColors.primaryTealDark : AppColors.primaryTeal,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? AppColors.headerGradientDark
                      : AppColors.headerGradient,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Appearance ───
                  Text('Appearance', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  _buildSettingCard(
                    theme: theme,
                    child: SwitchListTile(
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Switch between light and dark theme'),
                      value: themeProvider.isDark,
                      onChanged: (_) => themeProvider.toggleTheme(),
                      activeTrackColor: AppColors.accentLime,
                      secondary: Icon(
                        themeProvider.isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: isDark ? AppColors.accentLime : AppColors.primaryTeal,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── Currency ───
                  Text('Currency', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  _buildSettingCard(
                    theme: theme,
                    child: ListTile(
                      leading: Icon(
                        Icons.currency_exchange_rounded,
                        color: isDark ? AppColors.accentLime : AppColors.primaryTeal,
                      ),
                      title: const Text('Currency'),
                      subtitle: Text(currencyProvider.name),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      onTap: () => _showCurrencyPicker(context, currencyProvider),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── Security ───
                  Text('Security', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  _buildSettingCard(
                    theme: theme,
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            authService.authEnabled
                                ? Icons.lock_rounded
                                : Icons.lock_open_rounded,
                            color: authService.authEnabled
                                ? (isDark ? AppColors.accentLime : AppColors.primaryTeal)
                                : theme.iconTheme.color,
                          ),
                          title: Text(
                            authService.authEnabled
                                ? 'App Lock Enabled'
                                : 'App Lock',
                          ),
                          subtitle: Text(
                            authService.authEnabled
                                ? 'Locked with PIN'
                                : 'Set up a PIN',
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          onTap: () async {
                            if (authService.authEnabled) {
                              _showAuthOptions(context, authService);
                            } else {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PinSetupScreen(),
                                ),
                              );
                            }
                          },
                        ),
                        if (authService.authEnabled &&
                            authService.hasBiometrics) ...[
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: Icon(
                              Icons.fingerprint_rounded,
                              color: isDark ? AppColors.accentLime : AppColors.primaryTeal,
                            ),
                            title: const Text('Fingerprint'),
                            subtitle:
                                const Text('Unlock with Fingerprint'),
                            value: authService.biometricEnabled,
                            onChanged: (val) =>
                                authService.setBiometricEnabled(val),
                            activeTrackColor: AppColors.accentLime,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── Categories ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Categories',
                          style: theme.textTheme.headlineMedium),
                      IconButton(
                        onPressed: () =>
                            _showAddCategoryDialog(context, categoryProvider),
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.accentLime,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: AppColors.primaryTeal,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ...categoryProvider.categories.map((cat) {
                    final color = Color(
                      int.parse(cat.color.replaceFirst('#', '0xFF')),
                    );
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getCategoryIcon(cat.icon),
                            color: color,
                            size: 20,
                          ),
                        ),
                        title: Text(cat.name),
                        trailing: cat.id != null && cat.id! > 5
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: AppColors.error, size: 20),
                                onPressed: () => _confirmDeleteCategory(
                                    context, categoryProvider, cat.id!),
                              )
                            : Icon(Icons.lock_rounded,
                                size: 16, color: theme.textTheme.bodySmall?.color),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // ─── About ───
                  Text('About', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  _buildSettingCard(
                    theme: theme,
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.info_outline_rounded,
                              color: isDark ? AppColors.accentLime : AppColors.primaryTeal),
                          title: const Text('Money Tracker'),
                          subtitle: Text('Version $_appVersion'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.system_update_rounded,
                              color: isDark ? AppColors.accentLime : AppColors.primaryTeal),
                          title: const Text('Check for Updates'),
                          subtitle: const Text('Download the latest version'),
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          onTap: () => UpdateService.checkForUpdate(context),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.storage_rounded,
                              color: isDark ? AppColors.accentLime : AppColors.primaryTeal),
                          title: const Text('Data Storage'),
                          subtitle: const Text(
                            'All data is stored locally on your device. No data is sent to any server.',
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.security_rounded,
                              color: isDark ? AppColors.accentLime : AppColors.primaryTeal),
                          title: const Text('Privacy'),
                          subtitle: const Text(
                            'Your financial data never leaves your device.',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, CurrencyProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Currency',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...CurrencyProvider.currencies.map((c) {
              final isSelected = provider.code == c['code'];
              return ListTile(
                leading: Text(
                  c['symbol']!,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700),
                ),
                title: Text(c['name']!),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppColors.success)
                    : null,
                onTap: () {
                  provider.setCurrency(c['code']!);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAuthOptions(BuildContext context, AuthService authService) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Change PIN'),
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PinSetupScreen()),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.lock_open_rounded, color: Color(0xFFFF6B6B)),
              title: const Text('Disable App Lock',
                  style: TextStyle(color: Color(0xFFFF6B6B))),
              onTap: () async {
                Navigator.pop(ctx);
                await authService.disableAuth();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required ThemeData theme,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'description':
        return Icons.description_rounded;
      case 'security':
        return Icons.security_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  void _showAddCategoryDialog(
      BuildContext context, CategoryProvider provider) {
    final nameController = TextEditingController();
    String selectedColor = '#1B3A4B';
    String selectedIcon = 'category';

    final icons = {
      'category': Icons.category_rounded,
      'account_balance': Icons.account_balance_rounded,
      'savings': Icons.savings_rounded,
      'trending_up': Icons.trending_up_rounded,
      'description': Icons.description_rounded,
      'security': Icons.security_rounded,
      'wallet': Icons.wallet_rounded,
      'home': Icons.home_rounded,
      'business': Icons.business_rounded,
      'school': Icons.school_rounded,
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    hintText: 'Category name',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Icon'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: icons.entries.map((e) {
                    final isSelected = selectedIcon == e.key;
                    return GestureDetector(
                      onTap: () =>
                          setDialogState(() => selectedIcon = e.key),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryTeal
                              : AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          e.value,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Color'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppColors.categoryColors.map((color) {
                    final hex =
                        '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                    final isSelected = selectedColor == hex;
                    return GestureDetector(
                      onTap: () =>
                          setDialogState(() => selectedColor = hex),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                provider.addCategory(CategoryModel(
                  name: nameController.text.trim(),
                  icon: selectedIcon,
                  color: selectedColor,
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCategory(
      BuildContext context, CategoryProvider provider, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Category?'),
        content: const Text(
          'Entries using this category will keep their current type label.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteCategory(id);
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
