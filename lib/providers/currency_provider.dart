import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyProvider extends ChangeNotifier {
  static const _key = 'currency_code';

  static const List<Map<String, String>> currencies = [
    {'code': 'BDT', 'symbol': '৳', 'locale': 'en_IN', 'name': 'Bangladeshi Taka (৳)'},
    {'code': 'USD', 'symbol': '\$', 'locale': 'en_US', 'name': 'US Dollar (\$)'},
    {'code': 'EUR', 'symbol': '€', 'locale': 'en_EU', 'name': 'Euro (€)'},
    {'code': 'GBP', 'symbol': '£', 'locale': 'en_GB', 'name': 'British Pound (£)'},
    {'code': 'INR', 'symbol': '₹', 'locale': 'en_IN', 'name': 'Indian Rupee (₹)'},
    {'code': 'SAR', 'symbol': 'SAR', 'locale': 'en_US', 'name': 'Saudi Riyal (SAR)'},
    {'code': 'AED', 'symbol': 'AED', 'locale': 'en_US', 'name': 'UAE Dirham (AED)'},
  ];

  String _code = 'BDT';

  CurrencyProvider() {
    _loadFromPrefs();
  }

  String get code => _code;

  Map<String, String> get _current =>
      currencies.firstWhere((c) => c['code'] == _code,
          orElse: () => currencies.first);

  String get symbol => _current['symbol']!;
  String get locale => _current['locale']!;
  String get name => _current['name']!;

  String format(double amount, {int decimalDigits = 0}) {
    return NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: decimalDigits,
    ).format(amount);
  }

  String compact(double amount) {
    if (amount >= 100000) {
      return '$symbol${(amount / 100000).toStringAsFixed(1)}L';
    }
    if (amount >= 1000) {
      return '$symbol${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '$symbol${amount.toStringAsFixed(0)}';
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && currencies.any((c) => c['code'] == saved)) {
      _code = saved;
      notifyListeners();
    }
  }

  Future<void> setCurrency(String code) async {
    if (_code == code) return;
    _code = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }
}
