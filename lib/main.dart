import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'database/database_helper.dart';
import 'data/data_repository.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'providers/account_provider.dart';
import 'providers/entry_provider.dart';
import 'providers/category_provider.dart';
import 'providers/investment_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/home_shell.dart';
import 'screens/lock_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'widgets/glass_surface.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase once so legacy v2.x users can auto-migrate their
  // existing Firestore data safely into on-device SQLite.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }

  // Always use local SQLite as the active on-device repository; private Google
  // Drive syncs the complete snapshot automatically when signed in.
  DataStore.init(DatabaseHelper());

  runApp(const MoneyTrackerApp());
}

class MoneyTrackerApp extends StatelessWidget {
  const MoneyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => EntryProvider()),
        ChangeNotifierProvider(create: (_) => InvestmentProvider()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AccountProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Money Tracker',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            builder: (context, child) {
              final dark = Theme.of(context).brightness == Brightness.dark;
              SystemChrome.setSystemUIOverlayStyle(
                dark
                    ? SystemUiOverlayStyle.light.copyWith(
                        statusBarColor: Colors.transparent,
                        systemNavigationBarColor: AppColors.backgroundDark,
                      )
                    : SystemUiOverlayStyle.dark.copyWith(
                        statusBarColor: Colors.transparent,
                        systemNavigationBarColor: AppColors.backgroundLight,
                      ),
              );
              return child ?? const SizedBox.shrink();
            },
            home: const AppInitializer(),
          );
        },
      ),
    );
  }
}

/// Initializes local storage, one-time legacy Firebase migration, and Drive sync.
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer>
    with SingleTickerProviderStateMixin {
  bool _isInitialized = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      final themeProvider =
          Provider.of<ThemeProvider>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      final entryProvider =
          Provider.of<EntryProvider>(context, listen: false);
      final investmentProvider =
          Provider.of<InvestmentProvider>(context, listen: false);
      final currencyProvider =
          Provider.of<CurrencyProvider>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final notifProvider =
          Provider.of<NotificationProvider>(context, listen: false);
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);

      await themeProvider.init();
      await currencyProvider.init();

      accountProvider.bindProviders(
        categories: categoryProvider,
        entries: entryProvider,
        investments: investmentProvider,
        currency: currencyProvider,
      );

      // Migrate any existing v2.x Firebase data locally before loading UI data.
      await accountProvider.migrateLegacyFirebaseOnStartupIfNeeded(
        currencyProvider: currencyProvider,
      );

      await categoryProvider.loadCategories();
      await entryProvider.loadAll();
      await investmentProvider.loadInvestments();

      // Silent Google Drive restore/reconcile runs in background.
      unawaited(accountProvider.init().catchError((Object e) {
        debugPrint('Account init failed: $e');
      }));

      await authService.init();

      await notifProvider.init();
      notifProvider.generateFromEntries(entryProvider.upcomingEntries);

      final notificationService = NotificationService();
      await notificationService.init();
      final hasPermission = await notificationService.isPermissionGranted();
      if (!hasPermission) {
        await notificationService.requestPermission();
      }
      await notificationService
          .scheduleAllEntryNotifications(entryProvider.upcomingEntries);

      if (mounted) {
        setState(() => _isInitialized = true);
        _fadeController.forward();
      }
    } catch (e) {
      debugPrint('Error initializing app: $e');
      if (mounted) {
        setState(() => _isInitialized = true);
        _fadeController.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return _buildSplashScreen();
    }

    final authService = context.watch<AuthService>();
    if (authService.authEnabled && !authService.isAuthenticated) {
      return LockScreen(
        onAuthenticated: () => authService.unlock(),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: const HomeShell(),
    );
  }

  Widget _buildSplashScreen() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Center(
          child: GlassContainer(
            borderRadius: 28,
            blur: 14,
            elevated: true,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogoMark(size: 88),
                const SizedBox(height: 20),
                Text(
                  'Money Tracker',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Track your income & principal wealth',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.8,
                    color: isDark ? AppColors.accentLime : AppColors.primaryTeal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
