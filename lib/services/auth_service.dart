import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  static const _pinKey = 'app_pin';
  static const _authEnabledKey = 'auth_enabled';
  static const _biometricEnabledKey = 'biometric_enabled';

  bool _isAuthenticated = false;
  bool _authEnabled = false;
  bool _biometricEnabled = false;
  bool _hasBiometrics = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get authEnabled => _authEnabled;
  bool get biometricEnabled => _biometricEnabled;
  bool get hasBiometrics => _hasBiometrics;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _authEnabled = prefs.getBool(_authEnabledKey) ?? false;
    _biometricEnabled = prefs.getBool(_biometricEnabledKey) ?? false;
    _hasBiometrics = await _checkBiometrics();

    // If auth not enabled, auto-authenticate
    if (!_authEnabled) {
      _isAuthenticated = true;
    }
    notifyListeners();
  }

  Future<bool> _checkBiometrics() async {
    try {
      final canAuth = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canAuth && isDeviceSupported;
    } catch (e) {
      debugPrint('Biometric check error: $e');
      return false;
    }
  }

  /// Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      final result = await _localAuth.authenticate(
        localizedReason: 'Use your fingerprint to unlock MoneyTracker',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (result) {
        _isAuthenticated = true;
        notifyListeners();
      }
      return result;
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    }
  }

  /// Verify PIN
  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString(_pinKey);
    final isCorrect = savedPin == pin;
    if (isCorrect) {
      _isAuthenticated = true;
      notifyListeners();
    }
    return isCorrect;
  }

  /// Setup PIN (first time or change)
  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
    _authEnabled = true;
    await prefs.setBool(_authEnabledKey, true);
    notifyListeners();
  }

  /// Enable/disable biometric
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _biometricEnabled = enabled;
    await prefs.setBool(_biometricEnabledKey, enabled);
    notifyListeners();
  }

  /// Disable all auth
  Future<void> disableAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _authEnabled = false;
    _biometricEnabled = false;
    _isAuthenticated = true;
    await prefs.setBool(_authEnabledKey, false);
    await prefs.setBool(_biometricEnabledKey, false);
    await prefs.remove(_pinKey);
    notifyListeners();
  }

  /// Check if PIN is set
  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pinKey);
  }

  /// Lock the app (call when app goes to background)
  void lock() {
    if (_authEnabled) {
      _isAuthenticated = false;
      notifyListeners();
    }
  }

  /// Unlock the app after successful authentication
  void unlock() {
    _isAuthenticated = true;
    notifyListeners();
  }
}
