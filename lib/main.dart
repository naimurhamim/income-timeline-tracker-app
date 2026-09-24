import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/entry_provider.dart';
import 'providers/category_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/currency_provider.dart';
import 'screens/home_shell.dart';
import 'screens/lock_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          // Set system UI overlay style based on theme
          SystemChrome.setSystemUIOverlayStyle(
            themeProvider.isDark
                ? SystemUiOverlayStyle.light.copyWith(
                    statusBarColor: Colors.transparent,
                    systemNavigationBarColor: const Color(0xFF152D3A),
                  )
                : SystemUiOverlayStyle.dark.copyWith(
                    statusBarColor: Colors.transparent,
                    systemNavigationBarColor: Colors.white,
                  ),
          );

          return MaterialApp(
            title: 'Money Tracker',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const AppInitializer(),
          );
        },
      ),
    );
  }
}

/// Initializes data before showing the main app
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
      duration: const Duration(milliseconds: 800),
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
      // Get all providers before any awaits (BuildContext safety)
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      final entryProvider =
          Provider.of<EntryProvider>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);

      await categoryProvider.loadCategories();
      await entryProvider.loadAll();

      // Initialize auth
      await authService.init();

      // Initialize notifications
      final notificationService = NotificationService();
      await notificationService.init();

      // Request permission (Android 13+)
      final hasPermission = await notificationService.isPermissionGranted();
      if (!hasPermission) {
        await notificationService.requestPermission();
      }

      // Schedule notifications for all upcoming entries
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F2633), Color(0xFF0A1A24)],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1B3A4B), Color(0xFF2D5F4F)],
                ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/images/app_icon.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Money Tracker',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track your income timeline',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFFA8E06C),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
