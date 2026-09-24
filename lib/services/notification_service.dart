import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/entry.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    // Set local timezone - Bangladesh
    tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle tap on notification - can navigate to app
        debugPrint('Notification tapped: ${details.payload}');
      },
    );

    _initialized = true;
  }

  /// Request notification permission (Android 13+)
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Check if permission is granted
  Future<bool> isPermissionGranted() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.areNotificationsEnabled();
      return granted ?? false;
    }
    return true;
  }

  /// Schedule notifications for all upcoming entries
  Future<void> scheduleAllEntryNotifications(
      List<EntryModel> entries) async {
    if (!_initialized) await init();

    // Cancel all existing scheduled notifications first
    await _plugin.cancelAll();

    final now = DateTime.now();

    for (final entry in entries) {
      if (entry.isReceived) continue;
      if (entry.expectedDate.isBefore(now)) continue;

      final daysLeft = entry.expectedDate.difference(now).inDays;

      // Schedule 7 days before
      if (daysLeft >= 7) {
        await _scheduleNotification(
          id: (entry.id ?? 0) * 10 + 1,
          title: '📅 Income Reminder',
          body:
              '${entry.title} - ${entry.amount.toStringAsFixed(0)} due in 7 days',
          scheduledDate: entry.expectedDate.subtract(const Duration(days: 7)),
          payload: 'entry_${entry.id}',
        );
      }

      // Schedule 3 days before
      if (daysLeft >= 3) {
        await _scheduleNotification(
          id: (entry.id ?? 0) * 10 + 2,
          title: '⏰ Due in 3 Days!',
          body:
              '${entry.title} - ${entry.amount.toStringAsFixed(0)} - only 3 days left!',
          scheduledDate: entry.expectedDate.subtract(const Duration(days: 3)),
          payload: 'entry_${entry.id}',
        );
      }

      // Schedule on the day itself (9 AM)
      final dayOf = DateTime(
        entry.expectedDate.year,
        entry.expectedDate.month,
        entry.expectedDate.day,
        9,
        0,
      );
      if (dayOf.isAfter(now)) {
        await _scheduleNotification(
          id: (entry.id ?? 0) * 10 + 3,
          title: '💰 Income Due Today!',
          body: '${entry.title} - ${entry.amount.toStringAsFixed(0)} is expected today!',
          scheduledDate: dayOf,
          payload: 'entry_${entry.id}',
        );
      }
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    final now = DateTime.now();
    if (scheduledDate.isBefore(now)) return;

    try {
      final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'money_tracker_channel',
            'Income Reminders',
            channelDescription: 'Notifications for upcoming income',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to schedule notification $id: $e');
    }
  }

  /// Cancel all notifications for a specific entry
  Future<void> cancelEntryNotifications(int entryId) async {
    await _plugin.cancel(entryId * 10 + 1);
    await _plugin.cancel(entryId * 10 + 2);
    await _plugin.cancel(entryId * 10 + 3);
  }

  /// Show immediate notification (for testing or instant alerts)
  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();

    await _plugin.show(
      999,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'money_tracker_channel',
          'Income Reminders',
          channelDescription: 'Notifications for upcoming income',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }
}
