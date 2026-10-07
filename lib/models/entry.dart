import 'package:uuid/uuid.dart';

class EntryModel {
  /// Unique string ID (UUID). Safe to merge across devices.
  final String id;
  final String title;
  final double amount;
  final DateTime expectedDate;
  final String type; // 'FD', 'Savings', or custom category name
  final String? categoryId;
  final int priority; // 1=Low, 2=Medium, 3=High
  final String? notes;
  final bool isRecurring;
  final String? recurringType; // 'monthly', 'quarterly', 'half_yearly', 'yearly'
  final DateTime? recurringEndDate;
  final bool isReceived;
  final DateTime? receivedDate;
  final String? parentId; // ID of the recurring entry this received copy was created from
  final DateTime createdAt;
  final DateTime updatedAt;

  EntryModel({
    String? id,
    required this.title,
    required this.amount,
    required this.expectedDate,
    required this.type,
    this.categoryId,
    this.priority = 2,
    this.notes,
    this.isRecurring = false,
    this.recurringType,
    this.recurringEndDate,
    this.isReceived = false,
    this.receivedDate,
    this.parentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? newId(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  static const _uuid = Uuid();

  /// Generates a new unique entry ID.
  static String newId() => _uuid.v4();

  /// Same map format is used for SQLite, Firestore and JSON backups.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'expected_date': expectedDate.toIso8601String(),
      'type': type,
      'category_id': categoryId,
      'priority': priority,
      'notes': notes,
      'is_recurring': isRecurring ? 1 : 0,
      'recurring_type': recurringType,
      'recurring_end_date': recurringEndDate?.toIso8601String(),
      'is_received': isReceived ? 1 : 0,
      'received_date': receivedDate?.toIso8601String(),
      'parent_id': parentId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory EntryModel.fromMap(Map<String, dynamic> map) {
    return EntryModel(
      id: map['id'].toString(),
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      expectedDate: DateTime.parse(map['expected_date'] as String),
      type: map['type'] as String,
      categoryId: map['category_id']?.toString(),
      priority: (map['priority'] as num?)?.toInt() ?? 2,
      notes: map['notes'] as String?,
      isRecurring: _asBool(map['is_recurring']),
      recurringType: map['recurring_type'] as String?,
      recurringEndDate: _asDate(map['recurring_end_date']),
      isReceived: _asBool(map['is_received']),
      receivedDate: _asDate(map['received_date']),
      parentId: map['parent_id']?.toString(),
      createdAt: _asDate(map['created_at']) ?? DateTime.now(),
      updatedAt: _asDate(map['updated_at']) ?? DateTime.now(),
    );
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value == 1;
    return false;
  }

  static DateTime? _asDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  /// Sentinel value to explicitly pass null to nullable fields in [copyWith].
  static const _unset = Object();

  EntryModel copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? expectedDate,
    String? type,
    Object? categoryId = _unset,
    int? priority,
    Object? notes = _unset,
    bool? isRecurring,
    Object? recurringType = _unset,
    Object? recurringEndDate = _unset,
    bool? isReceived,
    Object? receivedDate = _unset,
    Object? parentId = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EntryModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      expectedDate: expectedDate ?? this.expectedDate,
      type: type ?? this.type,
      categoryId: categoryId == _unset ? this.categoryId : categoryId as String?,
      priority: priority ?? this.priority,
      notes: notes == _unset ? this.notes : notes as String?,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringType: recurringType == _unset ? this.recurringType : recurringType as String?,
      recurringEndDate: recurringEndDate == _unset ? this.recurringEndDate : recurringEndDate as DateTime?,
      isReceived: isReceived ?? this.isReceived,
      receivedDate: receivedDate == _unset ? this.receivedDate : receivedDate as DateTime?,
      parentId: parentId == _unset ? this.parentId : parentId as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Calculate next recurring date from the current expected date
  DateTime? getNextRecurringDate() {
    if (!isRecurring || recurringType == null) return null;

    DateTime? nextDate;
    switch (recurringType) {
      case 'monthly':
        nextDate = DateTime(
          expectedDate.year,
          expectedDate.month + 1,
          expectedDate.day,
        );
        break;
      case 'quarterly':
        nextDate = DateTime(
          expectedDate.year,
          expectedDate.month + 3,
          expectedDate.day,
        );
        break;
      case 'half_yearly':
        nextDate = DateTime(
          expectedDate.year,
          expectedDate.month + 6,
          expectedDate.day,
        );
        break;
      case 'yearly':
        nextDate = DateTime(
          expectedDate.year + 1,
          expectedDate.month,
          expectedDate.day,
        );
        break;
      default:
        return null;
    }

    if (recurringEndDate != null) {
      final end = DateTime(recurringEndDate!.year, recurringEndDate!.month, recurringEndDate!.day, 23, 59, 59);
      if (nextDate.isAfter(end)) {
        return null;
      }
    }
    return nextDate;
  }

  /// Days remaining until expected date
  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expected = DateTime(
      expectedDate.year,
      expectedDate.month,
      expectedDate.day,
    );
    return expected.difference(today).inDays;
  }

  /// Check if overdue
  bool get isOverdue => !isReceived && daysRemaining < 0;

  /// Check if due today
  bool get isDueToday => !isReceived && daysRemaining == 0;

  /// Human readable status
  String get statusText {
    if (isReceived) return 'Received';
    if (isDueToday) return 'Due Today';
    if (isOverdue) return 'Overdue (${-daysRemaining} days)';
    return '$daysRemaining days left';
  }
}
