class CategoryModel {
  final int? id;
  final String name;
  final String icon; // Material icon name
  final String color; // Hex color string
  final DateTime createdAt;

  CategoryModel({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

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
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: map['color'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  CategoryModel copyWith({
    int? id,
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
      name: 'FD',
      icon: 'account_balance',
      color: '#1B3A4B',
    ),
    CategoryModel(
      name: 'Savings',
      icon: 'savings',
      color: '#2D5F4F',
    ),
    CategoryModel(
      name: 'DPS',
      icon: 'trending_up',
      color: '#42A5F5',
    ),
    CategoryModel(
      name: 'Bond',
      icon: 'description',
      color: '#AB47BC',
    ),
    CategoryModel(
      name: 'Insurance',
      icon: 'security',
      color: '#FFA726',
    ),
  ];
}
