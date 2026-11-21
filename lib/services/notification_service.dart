import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/entry.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  bool get _supportsPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    // Set local timezone - Bangladesh
    tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

    if (!_supportsPlatform) {
      _initialized = true;
      return;
    }

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
        debugPrint('Notification tapped: ${details.payload}');
      },
    );

    _initialized = true;
  }

  /// Request notification permission (Android 13+)
  Future<bool> requestPermission() async {
    if (!_supportsPlatform) return true;
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
    if (!_supportsPlatform) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.areNotificationsEnabled();
      return granted ?? false;
    }
    return true;
  }

  /// Generates a stable, positive 31-bit int from a string ID.
  static int _stableNotifId(String entryId, int offset) {
    final hex = entryId.replaceAll('-', '');
    final base = int.parse(hex.substring(0, 8), radix: 16) & 0x7FFFFFFF;
    return (base % 100000000) * 3 + offset;
  }

  Future<AndroidScheduleMode> _preferredAndroidScheduleMode() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      final canExact = await android.canScheduleExactNotifications();
      return (canExact ?? false)
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (_) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  /// Schedule notifications for all upcoming entries (9:00 AM reminders).
  Future<void> scheduleAllEntryNotifications(List<EntryModel> entries) async {
    if (!_initialized) await init();
    if (!_supportsPlatform) return;

    await _plugin.cancelAll();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduleMode = await _preferredAndroidScheduleMode();

    for (final entry in entries) {
      if (entry.isReceived) continue;

      final dueDate = DateTime(
        entry.expectedDate.year,
        entry.expectedDate.month,
        entry.expectedDate.day,
      );
      if (dueDate.isBefore(today)) continue;

      final daysLeft = dueDate.difference(today).inDays;

      // Schedule 7 days before at 9:00 AM
      if (daysLeft >= 7) {
        final sevenDay = dueDate.subtract(const Duration(days: 7));
        await _scheduleNotification(
          id: _stableNotifId(entry.id, 0),
          title: '📅 Income Reminder',
          body:
              '${entry.title} - ${entry.amount.toStringAsFixed(0)} due in 7 days',
          scheduledDate:
              DateTime(sevenDay.year, sevenDay.month, sevenDay.day, 9, 0),
          scheduleMode: scheduleMode,
          payload: 'entry_${entry.id}',
        );
      }

      // Schedule 3 days before at 9:00 AM
      if (daysLeft >= 3) {
        final threeDay = dueDate.subtract(const Duration(days: 3));
        await _scheduleNotification(
          id: _stableNotifId(entry.id, 1),
          title: '⏰ Due in 3 Days!',
          body:
              '${entry.title} - ${entry.amount.toStringAsFixed(0)} - only 3 days left!',
          scheduledDate:
              DateTime(threeDay.year, threeDay.month, threeDay.day, 9, 0),
          scheduleMode: scheduleMode,
          payload: 'entry_${entry.id}',
        );
      }

      // Schedule on the day itself (9:00 AM)
      final dayOf = DateTime(
        entry.expectedDate.year,
        entry.expectedDate.month,
        entry.expectedDate.day,
        9,
        0,
      );
      if (dayOf.isAfter(now)) {
        await _scheduleNotification(
          id: _stableNotifId(entry.id, 2),
          title: '💰 Income Due Today!',
          body:
              '${entry.title} - ${entry.amount.toStringAsFixed(0)} is expected today!',
          scheduledDate: dayOf,
          scheduleMode: scheduleMode,
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
    required AndroidScheduleMode scheduleMode,
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
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to schedule notification $id: $e');
    }
  }

  /// Cancel all notifications for a specific entry
  Future<void> cancelEntryNotifications(String entryId) async {
    if (!_supportsPlatform) return;
    await _plugin.cancel(_stableNotifId(entryId, 0));
    await _plugin.cancel(_stableNotifId(entryId, 1));
    await _plugin.cancel(_stableNotifId(entryId, 2));
  }

  /// Show immediate notification (for testing or instant alerts)
  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();
    if (!_supportsPlatform) return;

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

  /// Requests permission if needed and triggers an immediate test notification.
  Future<String> showTestNotification() async {
    await init();
    if (!_supportsPlatform) {
      return 'Test notifications work on Android & iOS devices.';
    }
    var granted = await isPermissionGranted();
    if (!granted) {
      granted = await requestPermission();
    }
    if (!granted) {
      return 'Notification permission denied. Please enable notifications in App Settings.';
    }

    try {
      await _plugin.show(
        999999,
        'Money Tracker Reminder Active',
        'Notifications are working! You will receive reminders for your upcoming entries.',
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
      );
      return 'Test notification sent!';
    } catch (e) {
      return 'Failed to send notification: $e';
    }
  }
}
