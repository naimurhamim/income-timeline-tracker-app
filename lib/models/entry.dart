class EntryModel {
  final int? id;
  final String title;
  final double amount;
  final DateTime expectedDate;
  final String type; // 'FD', 'Savings', or custom category name
  final int? categoryId;
  final int priority; // 1=Low, 2=Medium, 3=High
  final String? notes;
  final bool isRecurring;
  final String? recurringType; // 'monthly', 'quarterly', 'half_yearly', 'yearly'
  final DateTime? recurringEndDate;
  final bool isReceived;
  final DateTime? receivedDate;
  final int? parentId; // ID of the recurring entry this received copy was created from
  final DateTime createdAt;
  final DateTime updatedAt;

  EntryModel({
    this.id,
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
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

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
      id: map['id'] as int?,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      expectedDate: DateTime.parse(map['expected_date'] as String),
      type: map['type'] as String,
      categoryId: map['category_id'] as int?,
      priority: map['priority'] as int? ?? 2,
      notes: map['notes'] as String?,
      isRecurring: (map['is_recurring'] as int?) == 1,
      recurringType: map['recurring_type'] as String?,
      recurringEndDate: map['recurring_end_date'] != null
          ? DateTime.parse(map['recurring_end_date'] as String)
          : null,
      isReceived: (map['is_received'] as int?) == 1,
      receivedDate: map['received_date'] != null
          ? DateTime.parse(map['received_date'] as String)
          : null,
      parentId: map['parent_id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Sentinel value to explicitly pass null to nullable fields in [copyWith].
  static const _unset = Object();

  EntryModel copyWith({
    Object? id = _unset,
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
      id: id == _unset ? this.id : id as int?,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      expectedDate: expectedDate ?? this.expectedDate,
      type: type ?? this.type,
      categoryId: categoryId == _unset ? this.categoryId : categoryId as int?,
      priority: priority ?? this.priority,
      notes: notes == _unset ? this.notes : notes as String?,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringType: recurringType == _unset ? this.recurringType : recurringType as String?,
      recurringEndDate: recurringEndDate == _unset ? this.recurringEndDate : recurringEndDate as DateTime?,
      isReceived: isReceived ?? this.isReceived,
      receivedDate: receivedDate == _unset ? this.receivedDate : receivedDate as DateTime?,
      parentId: parentId == _unset ? this.parentId : parentId as int?,
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
