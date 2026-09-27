import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/entry.dart';

/// A single in-app notification item shown in the bell popup.
class NotificationItem {
  final int entryId;
  final String title;
  final String body;
  final IconData icon;
  final String type; // 'overdue', 'today', '3day', '7day'
  final int daysLeft;

  /// Unique key used to track read/unread state.
  String get key => '${entryId}_$type';

  const NotificationItem({
    required this.entryId,
    required this.title,
    required this.body,
    required this.icon,
    required this.type,
    required this.daysLeft,
  });
}

class NotificationProvider extends ChangeNotifier {
  List<NotificationItem> _items = [];
  Set<String> _readKeys = {};
  bool _initialized = false;

  List<NotificationItem> get items => _items;
  int get unseenCount => _items.where((i) => !_readKeys.contains(i.key)).length;
  bool isRead(NotificationItem item) => _readKeys.contains(item.key);

  /// Load persisted read keys from SharedPreferences.
  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _readKeys = (prefs.getStringList('read_notification_keys') ?? []).toSet();
    _initialized = true;
  }

  /// Regenerate notification items from the current upcoming entries.
  void generateFromEntries(List<EntryModel> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final newItems = <NotificationItem>[];

    for (final entry in entries) {
      if (entry.isReceived) continue;

      final dueDate = DateTime(
        entry.expectedDate.year,
        entry.expectedDate.month,
        entry.expectedDate.day,
      );
      final daysLeft = dueDate.difference(today).inDays;
      final amountStr = entry.amount.toStringAsFixed(0);

      if (daysLeft < 0) {
        // Overdue
        newItems.add(NotificationItem(
          entryId: entry.id ?? 0,
          title: entry.title,
          body: '$amountStr was due ${-daysLeft} day${-daysLeft == 1 ? '' : 's'} ago',
          icon: Icons.warning_amber_rounded,
          type: 'overdue',
          daysLeft: daysLeft,
        ));
      } else if (daysLeft == 0) {
        // Due today
        newItems.add(NotificationItem(
          entryId: entry.id ?? 0,
          title: entry.title,
          body: '$amountStr is expected today!',
          icon: Icons.account_balance_wallet_rounded,
          type: 'today',
          daysLeft: 0,
        ));
      } else if (daysLeft <= 3) {
        // Due in 1-3 days
        newItems.add(NotificationItem(
          entryId: entry.id ?? 0,
          title: entry.title,
          body: '$amountStr due in $daysLeft day${daysLeft == 1 ? '' : 's'}',
          icon: Icons.schedule_rounded,
          type: '3day',
          daysLeft: daysLeft,
        ));
      } else if (daysLeft <= 7) {
        // Due in 4-7 days
        newItems.add(NotificationItem(
          entryId: entry.id ?? 0,
          title: entry.title,
          body: '$amountStr due in $daysLeft days',
          icon: Icons.event_note_rounded,
          type: '7day',
          daysLeft: daysLeft,
        ));
      }
    }

    // Sort: overdue first, then today, then nearest due
    newItems.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));

    // Prune read keys that are no longer relevant (entry was received/deleted)
    final currentKeys = newItems.map((i) => i.key).toSet();
    _readKeys = _readKeys.intersection(currentKeys);

    _items = newItems;
    notifyListeners();
  }

  /// Mark all current notifications as read.
  Future<void> markAllRead() async {
    _readKeys.addAll(_items.map((i) => i.key));
    await _persistReadKeys();
    notifyListeners();
  }

  Future<void> _persistReadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('read_notification_keys', _readKeys.toList());
  }
}
