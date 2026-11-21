import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/category.dart';
import '../providers/account_provider.dart';
import '../providers/category_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/entry_provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../theme/app_colors.dart';
import '../theme/glass_tokens.dart';
import '../widgets/account_card.dart';
import '../widgets/glass_surface.dart';
import 'pin_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _expandedSection;
  String _appVersion = '3.0.0';
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _checkNotificationPermission();
  }

  Future<void> _loadVersion() async {
    final version = await UpdateService.getCurrentVersion();
    if (mounted) setState(() => _appVersion = version);
  }

  Future<void> _checkNotificationPermission() async {
    final granted = await NotificationService().isPermissionGranted();
    if (mounted) setState(() => _notificationsEnabled = granted);
  }

  void _toggleSection(String key) {
    setState(() {
      _expandedSection = (_expandedSection == key) ? null : key;
    });
  }

  Future<void> _openExternalUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = context.glass;
    final isDark = theme.brightness == Brightness.dark;
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.railBreakpoint;

    final themeProvider = context.watch<ThemeProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final entryProvider = context.read<EntryProvider>();
    final authService = context.watch<AuthService>();
    final currencyProvider = context.watch<CurrencyProvider>();
    final account = context.watch<AccountProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                wide ? AppSpacing.xl : AppLayout.navClearance + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Header ───
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Settings',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (authService.authEnabled)
                        GlassCircleButton(
                          icon: Icons.lock_outline_rounded,
                          tooltip: 'Lock app now',
                          onTap: authService.lock,
                        )
                      else if (account.isSignedIn)
                        GlassCircleButton(
                          icon: Icons.logout_rounded,
                          tooltip: 'Sign out',
                          onTap: account.signOut,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ─── Profile Hero Card ───
                  GlassContainer(
                    borderRadius: AppRadius.lg,
                    blur: 0,
                    elevated: true,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _ProfileAvatar(
                          photoUrl: account.photoUrl,
                          name: account.isSignedIn
                              ? account.displayName
                              : 'Money Tracker',
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.isSignedIn
                                    ? account.displayName
                                    : 'Money Tracker',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                account.isSignedIn
                                    ? (account.email.isNotEmpty
                                        ? account.email
                                        : 'Private Google Drive')
                                    : 'Local device profile',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  if (!account.isSignedIn)
                                    GlassPillButton(
                                      icon: Icons.login_rounded,
                                      label: account.isAvailable
                                          ? 'Google Sign-In'
                                          : 'Data Backup',
                                      onTap: () {
                                        if (account.isAvailable) {
                                          account.signIn();
                                        } else {
                                          _toggleSection('cloud');
                                        }
                                      },
                                    )
                                  else ...[
                                    GlassPillButton(
                                      icon: Icons.cloud_upload_outlined,
                                      label: account.isSyncing
                                          ? 'Syncing...'
                                          : 'Backup',
                                      onTap: account.backupNow,
                                    ),
                                    GlassPillButton(
                                      icon: Icons.cloud_download_outlined,
                                      label: 'Restore',
                                      onTap: () => _toggleSection('cloud'),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ─── Settings Accordion Card ───
                  GlassContainer(
                    borderRadius: AppRadius.lg,
                    blur: 0,
                    elevated: true,
                    child: Column(
                      children: [
                        // 1. Google Drive & Data Backup
                        _AccordionSection(
                          icon: Icons.cloud_outlined,
                          title: 'Google Drive & Data Backup',
                          subtitle: account.isSignedIn
                              ? 'Private Drive (${account.email.isNotEmpty ? account.email : 'Connected'})'
                              : 'Private Google Drive sync & JSON Export/Import',
                          expanded: _expandedSection == 'cloud',
                          onToggle: () => _toggleSection('cloud'),
                          child: const Padding(
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              0,
                              AppSpacing.md,
                              AppSpacing.md,
                            ),
                            child: AccountCard(),
                          ),
                        ),
                        const Divider(height: 1),

                        // 2. Appearance
                        _AccordionSection(
                          icon: Icons.palette_outlined,
                          title: 'Appearance',
                          subtitle: _themeLabel(themeProvider.themeMode),
                          expanded: _expandedSection == 'appearance',
                          onToggle: () => _toggleSection('appearance'),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              0,
                              AppSpacing.md,
                              AppSpacing.md,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<ThemeMode>(
                                segments: const [
                                  ButtonSegment(
                                    value: ThemeMode.system,
                                    icon: Icon(Icons.brightness_auto_outlined),
                                    label: Text('System'),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.light,
                                    icon: Icon(Icons.light_mode_outlined),
                                    label: Text('Light'),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.dark,
                                    icon: Icon(Icons.dark_mode_outlined),
                                    label: Text('Dark'),
                                  ),
                                ],
                                selected: {themeProvider.themeMode},
                                onSelectionChanged: (selected) {
                                  themeProvider.setThemeMode(selected.first);
                                },
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1),

                        // 3. Currency
                        _SettingsRow(
                          icon: Icons.currency_exchange_rounded,
                          title: 'Currency',
                          subtitle: currencyProvider.name,
                          onTap: () =>
                              _showCurrencyPicker(context, currencyProvider),
                        ),
                        const Divider(height: 1),

                        // 4. Notifications & Reminders (with Test Notification button!)
                        _AccordionSection(
                          icon: Icons.notifications_none_rounded,
                          title: 'Notifications & Reminders',
                          subtitle: _notificationsEnabled
                              ? 'Enabled · 7-day, 3-day & due-day 9:00 AM alerts'
                              : 'Permission needed or paused',
                          expanded: _expandedSection == 'notifications',
                          onToggle: () => _toggleSection('notifications'),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              0,
                              AppSpacing.md,
                              AppSpacing.md,
                            ),
                            child: GlassContainer(
                              borderRadius: AppRadius.md,
                              blur: 0,
                              fillColor: g.surfaceSubtle,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _notificationsEnabled
                                            ? Icons.notifications_active_rounded
                                            : Icons.notifications_off_rounded,
                                        color: _notificationsEnabled
                                            ? g.success
                                            : g.warning,
                                        size: 20,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          _notificationsEnabled
                                              ? 'System notification permission is granted.'
                                              : 'Tap Test Notification to request notification permission.',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(color: g.textPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  OutlinedButton.icon(
                                    key: const Key('test_notification_button'),
                                    onPressed: () async {
                                      final messenger =
                                          ScaffoldMessenger.of(context);
                                      final msg = await NotificationService()
                                          .showTestNotification();
                                      await _checkNotificationPermission();
                                      messenger.showSnackBar(
                                        SnackBar(content: Text(msg)),
                                      );
                                    },
                                    icon: const Icon(
                                        Icons.notifications_outlined,
                                        size: 18),
                                    label:
                                        const Text('Send Test Notification'),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final messenger =
                                          ScaffoldMessenger.of(context);
                                      await NotificationService()
                                          .scheduleAllEntryNotifications(
                                        entryProvider.allUpcoming,
                                      );
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'All upcoming entry reminders rescheduled.',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.refresh_rounded,
                                        size: 18),
                                    label: const Text('Reschedule Reminders'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1),

                        // 5. Privacy & App Lock
                        _AccordionSection(
                          icon: authService.authEnabled
                              ? Icons.lock_rounded
                              : Icons.lock_outline_rounded,
                          title: 'Privacy & App Lock',
                          subtitle: authService.authEnabled
                              ? (authService.biometricEnabled
                                  ? 'PIN + Fingerprint Lock enabled'
                                  : 'PIN Lock enabled')
                              : 'Protect financial records with PIN + Fingerprint',
                          expanded: _expandedSection == 'privacy',
                          onToggle: () => _toggleSection('privacy'),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              0,
                              AppSpacing.md,
                              AppSpacing.md,
                            ),
                            child: GlassContainer(
                              borderRadius: AppRadius.md,
                              blur: 0,
                              fillColor: g.surfaceSubtle,
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: Icon(
                                      authService.authEnabled
                                          ? Icons.lock_rounded
                                          : Icons.lock_open_rounded,
                                      color: authService.authEnabled
                                          ? g.primary
                                          : g.textSecondary,
                                    ),
                                    title: Text(authService.authEnabled
                                        ? 'App Lock Enabled'
                                        : 'Set Up App Lock'),
                                    subtitle: Text(authService.authEnabled
                                        ? 'Change or disable PIN'
                                        : 'Require PIN on launch'),
                                    trailing: const Icon(
                                        Icons.chevron_right_rounded),
                                    onTap: () async {
                                      if (authService.authEnabled) {
                                        _showAuthOptions(context, authService);
                                      } else {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const PinSetupScreen(),
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
                                        color: g.primary,
                                      ),
                                      title: const Text('Fingerprint'),
                                      subtitle: const Text(
                                          'Unlock with Fingerprint'),
                                      value: authService.biometricEnabled,
                                      onChanged: authService.setBiometricEnabled,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1),

                        // 6. Categories
                        _AccordionSection(
                          icon: Icons.category_outlined,
                          title: 'Categories',
                          subtitle:
                              '${categoryProvider.categories.length} entry categories configured',
                          expanded: _expandedSection == 'categories',
                          onToggle: () => _toggleSection('categories'),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              0,
                              AppSpacing.md,
                              AppSpacing.md,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ...categoryProvider.categories.map((cat) {
                                  final rawColor = Color(
                                    int.parse(
                                        cat.color.replaceFirst('#', '0xFF')),
                                  );
                                  final catColor = AppColors.adaptiveColor(
                                      rawColor, isDark);

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: GlassContainer(
                                      borderRadius: AppRadius.md,
                                      blur: 0,
                                      fillColor: g.surfaceSubtle,
                                      child: ListTile(
                                        leading: Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: catColor.withValues(
                                                alpha: isDark ? 0.22 : 0.14),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            _getCategoryIcon(cat.icon),
                                            color: catColor,
                                            size: 20,
                                          ),
                                        ),
                                        title: Text(cat.name),
                                        trailing: !cat.isDefault
                                            ? IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  color: AppColors.error,
                                                  size: 20,
                                                ),
                                                onPressed: () =>
                                                    _confirmDeleteCategory(
                                                  context,
                                                  categoryProvider,
                                                  cat.id,
                                                ),
                                              )
                                            : Icon(
                                                Icons.lock_rounded,
                                                size: 16,
                                                color: g.textSecondary,
                                              ),
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(height: 4),
                                OutlinedButton.icon(
                                  onPressed: () => _showAddCategoryDialog(
                                      context, categoryProvider),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Add Custom Category'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ─── About ───
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
                    child: Text(
                      'About',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: g.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GlassContainer(
                    borderRadius: AppRadius.lg,
                    blur: 0,
                    elevated: true,
                    child: Column(
                      children: [
                        _AboutInfoRow(
                          icon: Icons.info_outline_rounded,
                          title: 'Money Tracker',
                          subtitle: 'Version $_appVersion',
                        ),
                        const Divider(height: 1),
                        _SettingsRow(
                          icon: Icons.system_update_rounded,
                          title: 'Check for Updates',
                          subtitle: 'Verify latest release on GitHub',
                          onTap: () => UpdateService.checkForUpdate(context),
                        ),
                        const Divider(height: 1),
                        const _AboutInfoRow(
                          icon: Icons.storage_outlined,
                          title: 'Data Storage',
                          subtitle:
                              'On-device SQLite + private Google Drive (appDataFolder)',
                        ),
                        const Divider(height: 1),
                        const _AboutInfoRow(
                          icon: Icons.verified_user_outlined,
                          title: 'Privacy',
                          subtitle:
                              'Backups stay in your own Google Drive; zero third-party server access',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ─── Developer ───
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
                    child: Text(
                      'Developer',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: g.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GlassContainer(
                    borderRadius: AppRadius.lg,
                    blur: 0,
                    elevated: true,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: g.glassBorder),
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/Naimur_Hamim.jpg',
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const AppLogoMark(size: 56),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MD Naimur Rashid',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Creator',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: g.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Divider(height: 1),
                        _DeveloperLinkRow(
                          icon: Icons.language_rounded,
                          label: 'Website',
                          value: 'naimurrashid.dev',
                          onTap: () =>
                              _openExternalUrl('https://naimurrashid.dev/'),
                        ),
                        const Divider(height: 1),
                        _DeveloperLinkRow(
                          icon: Icons.code_rounded,
                          label: 'GitHub',
                          value: 'github.com/naimurhamim',
                          onTap: () =>
                              _openExternalUrl('https://github.com/naimurhamim'),
                        ),
                        const Divider(height: 1),
                        _DeveloperLinkRow(
                          icon: Icons.work_outline_rounded,
                          label: 'LinkedIn',
                          value: 'md-naimur-rashid',
                          onTap: () => _openExternalUrl(
                            'https://www.linkedin.com/in/md-naimur-rashid/',
                          ),
                        ),
                      ],
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

  static String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light Glass';
      case ThemeMode.dark:
        return 'Dark Glass';
      case ThemeMode.system:
        return 'Follow System';
    }
  }

  void _showCurrencyPicker(BuildContext context, CurrencyProvider provider) {
    final g = context.glass;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: g.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          border: Border.all(color: g.glassBorder),
        ),
        child: SafeArea(
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
                      ? Icon(Icons.check_circle_rounded, color: g.success)
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
      ),
    );
  }

  void _showAuthOptions(BuildContext context, AuthService authService) {
    final g = context.glass;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: g.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          border: Border.all(color: g.glassBorder),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
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
                    const Icon(Icons.lock_open_rounded, color: AppColors.error),
                title: const Text('Disable App Lock',
                    style: TextStyle(color: AppColors.error)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await authService.disableAuth();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
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
    final g = context.glass;
    final nameController = TextEditingController();
    var selectedColor = '#1B3A4B';
    var selectedIcon = 'category';

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

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: g.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: g.glassBorder),
          ),
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
                          color: isSelected ? g.primary : g.surfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          e.value,
                          color: isSelected ? g.onPrimary : g.textSecondary,
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
            FilledButton(
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
      BuildContext context, CategoryProvider provider, String id) {
    final g = context.glass;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: g.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: g.glassBorder),
        ),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.photoUrl, required this.name});

  final String? photoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    if (hasPhoto) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Image.network(
          photoUrl!,
          width: 68,
          height: 68,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const AppLogoMark(size: 68),
        ),
      );
    }
    return const AppLogoMark(size: 68);
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.quarterTurns = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final double quarterTurns;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: g.surfaceSubtle,
              ),
              child: Icon(icon, size: 19, color: g.textPrimary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: quarterTurns,
              duration: const Duration(milliseconds: 180),
              child: Icon(Icons.chevron_right_rounded, color: g.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccordionSection extends StatelessWidget {
  const _AccordionSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SettingsRow(
          icon: icon,
          title: title,
          subtitle: subtitle,
          onTap: onToggle,
          quarterTurns: expanded ? 0.25 : 0,
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: child,
          crossFadeState:
              expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
          sizeCurve: Curves.easeOutCubic,
        ),
      ],
    );
  }
}

class _AboutInfoRow extends StatelessWidget {
  const _AboutInfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.md, color: g.textPrimary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: g.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeveloperLinkRow extends StatelessWidget {
  const _DeveloperLinkRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 19, color: g.primary),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              value,
              style: textTheme.bodySmall?.copyWith(color: g.textSecondary),
            ),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new_rounded, size: 15, color: g.textSecondary),
          ],
        ),
      ),
    );
  }
}
