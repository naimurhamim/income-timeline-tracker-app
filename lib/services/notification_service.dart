import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/entry.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _channelId = 'money_tracker_channel_v2';
  static const String _channelName = 'Income Reminders';
  static const String _channelDescription = 'Notifications for upcoming income';
  static const String _prefHourKey = 'notif_reminder_hour_v1';
  static const String _prefMinuteKey = 'notif_reminder_minute_v1';
  static const int _testScheduledId = 999998;
  static const int _testInstantId = 999999;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Future<void>? _initFuture;
  bool _permissionRequestInFlight = false;
  int _reminderHour = 9;
  int _reminderMinute = 0;

  int get reminderHour => _reminderHour;
  int get reminderMinute => _reminderMinute;
  String get formattedReminderTime =>
      formatHourMinute(_reminderHour, _reminderMinute);

  /// Formats 24-hour [hour]:[minute] into concise 12-hour clock display.
  static String formatHourMinute(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Returns [target] when in the future, or `now + 5s` if [target] is in the current minute (< 60s ago).
  static DateTime? computeEffectiveScheduleTime(
    DateTime target,
    DateTime now,
  ) {
    if (target.isAfter(now)) return target;
    final elapsed = now.difference(target);
    if (!elapsed.isNegative &&
        elapsed.inSeconds < 60 &&
        target.year == now.year &&
        target.month == now.month &&
        target.day == now.day &&
        target.hour == now.hour &&
        target.minute == now.minute) {
      return now.add(const Duration(seconds: 5));
    }
    return null;
  }

  bool get _supportsPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> init() {
    if (_initialized) return Future<void>.value();
    return _initFuture ??= _doInit();
  }

  Future<void> _doInit() async {
    try {
      await _loadSavedReminderTime();

      tz.initializeTimeZones();
      tz.setLocalLocation(_resolveLocalLocation(DateTime.now()));

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

      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          final android = _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
          await android?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );
        } catch (e) {
          debugPrint('Notification channel init warning: $e');
        }
      }

      _initialized = true;
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _loadSavedReminderTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final h = prefs.getInt(_prefHourKey);
      final m = prefs.getInt(_prefMinuteKey);
      if (h != null && h >= 0 && h <= 23) _reminderHour = h;
      if (m != null && m >= 0 && m <= 59) _reminderMinute = m;
    } catch (_) {}
  }

  tz.Location _resolveLocalLocation(DateTime now) {
    final offsetMs = now.timeZoneOffset.inMilliseconds;
    if (offsetMs == const Duration(hours: 6).inMilliseconds &&
        tz.timeZoneDatabase.locations.containsKey('Asia/Dhaka')) {
      return tz.getLocation('Asia/Dhaka');
    }
    for (final entry in tz.timeZoneDatabase.locations.entries) {
      if (entry.value.currentTimeZone.offset == offsetMs &&
          !entry.key.startsWith('Etc/')) {
        return entry.value;
      }
    }
    if (tz.timeZoneDatabase.locations.containsKey('Asia/Dhaka')) {
      return tz.getLocation('Asia/Dhaka');
    }
    return tz.UTC;
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Requests notification permission first, then exact alarm permission sequentially.
  Future<bool> requestPermission() async {
    await init();
    if (!_supportsPlatform) return true;
    if (_permissionRequestInFlight) return isPermissionGranted();
    _permissionRequestInFlight = true;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        bool granted;
        try {
          granted = await android.requestNotificationsPermission() ?? true;
        } catch (_) {
          granted = await isPermissionGranted();
        }
        try {
          final canExact = await android.canScheduleExactNotifications();
          if (canExact == false) {
            await android.requestExactAlarmsPermission();
          }
        } catch (_) {}
        return granted;
      }
      return true;
    } finally {
      _permissionRequestInFlight = false;
    }
  }

  Future<void> _ensureExactAlarmPermission() async {
    if (!_supportsPlatform || _permissionRequestInFlight) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    _permissionRequestInFlight = true;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return;
      final canExact = await android.canScheduleExactNotifications();
      if (canExact == false) {
        await android.requestExactAlarmsPermission();
      }
    } catch (_) {
    } finally {
      _permissionRequestInFlight = false;
    }
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

  /// Updates the custom reminder clock time and reschedules upcoming entry reminders.
  Future<void> setReminderTime(
    int hour,
    int minute, {
    List<EntryModel>? upcomingEntries,
  }) async {
    await init();
    _reminderHour = hour.clamp(0, 23);
    _reminderMinute = minute.clamp(0, 59);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefHourKey, _reminderHour);
      await prefs.setInt(_prefMinuteKey, _reminderMinute);
    } catch (_) {}
    if (upcomingEntries != null) {
      await scheduleAllEntryNotifications(upcomingEntries);
    }
  }

  /// Returns how many pending reminders are currently queued on this device.
  Future<int> pendingNotificationCount() async {
    await init();
    if (!_supportsPlatform) return 0;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.length;
    } catch (_) {
      return 0;
    }
  }

  /// Generates a stable, positive 31-bit int from any entry ID string.
  @visibleForTesting
  static int stableNotifId(String entryId, int offset) {
    final hex = entryId.replaceAll('-', '');
    final parsed = hex.length >= 8
        ? int.tryParse(hex.substring(0, 8), radix: 16)
        : null;
    if (parsed != null) {
      final base = (parsed & 0x7FFFFFFF) % 100000000;
      return (base == 0 && offset == 0 ? 1 : base) * 3 + offset;
    }
    var hash = 2166136261;
    for (final unit in entryId.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7FFFFFFF;
    }
    final mod = hash % 100000000;
    final base = (mod == 0 && offset == 0) ? 1 : mod;
    return base * 3 + offset;
  }

  static int _stableNotifId(String entryId, int offset) =>
      stableNotifId(entryId, offset);

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

  /// Schedule notifications for all upcoming entries using the configured custom reminder time.
  Future<void> scheduleAllEntryNotifications(List<EntryModel> entries) async {
    await init();
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

      // Schedule 7 days before at configured reminder time
      final sevenDay = dueDate.subtract(const Duration(days: 7));
      final sevenTarget = computeEffectiveScheduleTime(
        DateTime(
          sevenDay.year,
          sevenDay.month,
          sevenDay.day,
          _reminderHour,
          _reminderMinute,
        ),
        now,
      );
      if (sevenTarget != null) {
        await _scheduleNotification(
          id: _stableNotifId(entry.id, 0),
          title: '📅 Income Reminder',
          body:
              '${entry.title} - ${entry.amount.toStringAsFixed(0)} due in 7 days',
          scheduledDate: sevenTarget,
          scheduleMode: scheduleMode,
          payload: 'entry_${entry.id}',
        );
      }

      // Schedule 3 days before at configured reminder time
      final threeDay = dueDate.subtract(const Duration(days: 3));
      final threeTarget = computeEffectiveScheduleTime(
        DateTime(
          threeDay.year,
          threeDay.month,
          threeDay.day,
          _reminderHour,
          _reminderMinute,
        ),
        now,
      );
      if (threeTarget != null) {
        await _scheduleNotification(
          id: _stableNotifId(entry.id, 1),
          title: '⏰ Due in 3 Days!',
          body:
              '${entry.title} - ${entry.amount.toStringAsFixed(0)} - only 3 days left!',
          scheduledDate: threeTarget,
          scheduleMode: scheduleMode,
          payload: 'entry_${entry.id}',
        );
      }

      // Schedule on the due day itself at configured reminder time
      final dayOfTarget = computeEffectiveScheduleTime(
        DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day,
          _reminderHour,
          _reminderMinute,
        ),
        now,
      );
      if (dayOfTarget != null) {
        await _scheduleNotification(
          id: _stableNotifId(entry.id, 2),
          title: '💰 Income Due Today!',
          body:
              '${entry.title} - ${entry.amount.toStringAsFixed(0)} is expected today!',
          scheduledDate: dayOfTarget,
          scheduleMode: scheduleMode,
          payload: 'entry_${entry.id}',
        );
      }
    }
  }

  Future<void> _zonedScheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime tzDate,
    required AndroidScheduleMode preferredMode,
    String? payload,
  }) async {
    final modes = <AndroidScheduleMode>[
      preferredMode,
      if (preferredMode != AndroidScheduleMode.inexactAllowWhileIdle)
        AndroidScheduleMode.inexactAllowWhileIdle,
    ];

    for (final mode in modes) {
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tzDate,
          _notificationDetails(),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        return;
      } catch (e) {
        debugPrint('zonedSchedule failed for mode $mode (id=$id): $e');
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
    if (!scheduledDate.isAfter(DateTime.now())) return;

    final tzDate = tz.TZDateTime(
      tz.local,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      scheduledDate.hour,
      scheduledDate.minute,
      scheduledDate.second,
    );

    await _zonedScheduleWithFallback(
      id: id,
      title: title,
      body: body,
      tzDate: tzDate,
      preferredMode: scheduleMode,
      payload: payload,
    );
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
    await init();
    if (!_supportsPlatform) return;

    await _plugin.show(
      999,
      title,
      body,
      _notificationDetails(),
    );
  }

  /// Requests permissions, shows an instant test alert, and queues a 10-second scheduled alarm.
  Future<String> showTestNotification() async {
    await init();
    if (!_supportsPlatform) {
      return 'Test notifications work on Android & iOS devices.';
    }
    var granted = await isPermissionGranted();
    if (!granted) {
      granted = await requestPermission();
    } else {
      await _ensureExactAlarmPermission();
    }
    if (!granted) {
      return 'Notification permission denied. Please enable notifications in App Settings.';
    }

    try {
      await _plugin.show(
        _testInstantId,
        'Money Tracker Reminder Active',
        'Immediate alert working! A 10-second scheduled background alarm has also been queued.',
        _notificationDetails(),
      );

      final mode = await _preferredAndroidScheduleMode();
      final scheduledAt =
          tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
      await _zonedScheduleWithFallback(
        id: _testScheduledId,
        title: '⏰ Scheduled Reminder Verified',
        body:
            'Background scheduled notifications are working at your custom time ($formattedReminderTime).',
        tzDate: scheduledAt,
        preferredMode: mode,
        payload: 'test_scheduled',
      );

      final count = await pendingNotificationCount();
      return 'Test notification sent + 10s scheduled alarm queued ($count active reminder${count == 1 ? '' : 's'}).';
    } catch (e) {
      return 'Failed to send notification: $e';
    }
  }
}
