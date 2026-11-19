import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_colors.dart';

/// Preset metadata for a built-in or custom investment type.
class InvestmentTypePreset {
  final String name;
  final String icon;
  final String color;

  const InvestmentTypePreset({
    required this.name,
    required this.icon,
    required this.color,
  });

  Color get displayColor => InvestmentModel.parseColor(color);
}

/// Represents a principal capital investment record (e.g. FD, Savings, Gold, Pension).
class InvestmentModel {
  final String id;
  final String title;
  final double amount;
  final String type;
  final String icon;
  final String color;
  final DateTime investedDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const _uuid = Uuid();
  static const _unset = Object();

  InvestmentModel({
    String? id,
    required this.title,
    required this.amount,
    required this.type,
    this.icon = 'wallet',
    this.color = '#1B3A4B',
    DateTime? investedDate,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? newId(),
        investedDate = investedDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Generates a new unique investment ID.
  static String newId() => _uuid.v4();

  /// Built-in principal investment types.
  static const List<InvestmentTypePreset> defaultTypes = [
    InvestmentTypePreset(
      name: 'FD',
      icon: 'account_balance',
      color: '#1B3A4B',
    ),
    InvestmentTypePreset(
      name: 'Savings',
      icon: 'savings',
      color: '#2D5F4F',
    ),
    InvestmentTypePreset(
      name: 'Gold',
      icon: 'diamond',
      color: '#D4A017',
    ),
    InvestmentTypePreset(
      name: 'Pension',
      icon: 'elderly',
      color: '#5C6BC0',
    ),
    InvestmentTypePreset(
      name: 'DPS',
      icon: 'trending_up',
      color: '#42A5F5',
    ),
    InvestmentTypePreset(
      name: 'Bond',
      icon: 'description',
      color: '#AB47BC',
    ),
    InvestmentTypePreset(
      name: 'Property',
      icon: 'home',
      color: '#26A69A',
    ),
    InvestmentTypePreset(
      name: 'Stock',
      icon: 'candlestick_chart',
      color: '#EF5350',
    ),
  ];

  /// Supported Material icons for built-in and custom investment types.
  static const Map<String, IconData> iconOptions = {
    'account_balance': Icons.account_balance_rounded,
    'savings': Icons.savings_rounded,
    'diamond': Icons.diamond_rounded,
    'elderly': Icons.elderly_rounded,
    'trending_up': Icons.trending_up_rounded,
    'description': Icons.description_rounded,
    'home': Icons.home_rounded,
    'candlestick_chart': Icons.candlestick_chart_rounded,
    'wallet': Icons.account_balance_wallet_rounded,
    'business': Icons.business_rounded,
    'currency_bitcoin': Icons.currency_bitcoin_rounded,
    'school': Icons.school_rounded,
    'star': Icons.star_rounded,
    'category': Icons.category_rounded,
  };

  /// Returns the Material [IconData] for an icon key.
  static IconData iconDataFor(String iconKey) {
    return iconOptions[iconKey] ?? Icons.account_balance_wallet_rounded;
  }

  /// Looks up a built-in preset by type name (case-insensitive).
  static InvestmentTypePreset? presetForType(String type) {
    final normalized = type.trim().toLowerCase();
    for (final preset in defaultTypes) {
      if (preset.name.toLowerCase() == normalized) return preset;
    }
    return null;
  }

  /// Safely parses a hex color string like `#1B3A4B`.
  static Color parseColor(String hex) {
    try {
      final cleaned = hex.trim().replaceFirst('#', '');
      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      }
      if (cleaned.length == 8) {
        return Color(int.parse(cleaned, radix: 16));
      }
    } catch (_) {}
    return AppColors.primaryTeal;
  }

  Color get displayColor => parseColor(color);

  /// Same map format is used for SQLite, Firestore and JSON backups.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type,
      'icon': icon,
      'color': color,
      'invested_date': investedDate.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory InvestmentModel.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return InvestmentModel(
      id: map['id'].toString(),
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      icon: map['icon'] as String? ?? 'wallet',
      color: map['color'] as String? ?? '#1B3A4B',
      investedDate: _asDate(map['invested_date']) ?? now,
      notes: map['notes'] as String?,
      createdAt: _asDate(map['created_at']) ?? now,
      updatedAt: _asDate(map['updated_at']) ?? now,
    );
  }

  static DateTime? _asDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  InvestmentModel copyWith({
    String? id,
    String? title,
    double? amount,
    String? type,
    String? icon,
    String? color,
    DateTime? investedDate,
    Object? notes = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InvestmentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      investedDate: investedDate ?? this.investedDate,
      notes: notes == _unset ? this.notes : notes as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
