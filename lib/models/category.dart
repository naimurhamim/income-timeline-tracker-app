import 'package:uuid/uuid.dart';

class CategoryModel {
  /// Unique string ID. Default categories use fixed IDs (e.g. `default_fd`)
  /// so they never duplicate when data from multiple devices is merged.
  final String id;
  final String name;
  final String icon; // Material icon name
  final String color; // Hex color string
  final DateTime createdAt;

  static const _uuid = Uuid();
  static const String defaultIdPrefix = 'default_';

  CategoryModel({
    String? id,
    required this.name,
    required this.icon,
    required this.color,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Built-in categories cannot be deleted.
  bool get isDefault => id.startsWith(defaultIdPrefix);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'].toString(),
      name: map['name'] as String,
      icon: map['icon'] as String? ?? 'category',
      color: map['color'] as String? ?? '#1B3A4B',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Default categories
  static List<CategoryModel> defaultCategories = [
    CategoryModel(
      id: 'default_fd',
      name: 'FD',
      icon: 'account_balance',
      color: '#1B3A4B',
    ),
    CategoryModel(
      id: 'default_savings',
      name: 'Savings',
      icon: 'savings',
      color: '#2D5F4F',
    ),
    CategoryModel(
      id: 'default_dps',
      name: 'DPS',
      icon: 'trending_up',
      color: '#42A5F5',
    ),
    CategoryModel(
      id: 'default_bond',
      name: 'Bond',
      icon: 'description',
      color: '#AB47BC',
    ),
    CategoryModel(
      id: 'default_insurance',
      name: 'Insurance',
      icon: 'security',
      color: '#FFA726',
    ),
  ];

  /// Returns the fixed default ID for a built-in category name, if any.
  static String? defaultIdForName(String name) {
    final lower = name.trim().toLowerCase();
    for (final c in defaultCategories) {
      if (c.name.toLowerCase() == lower) return c.id;
    }
    return null;
  }
}
