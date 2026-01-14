import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/habit.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  bool _isInitialized = false;

  NotificationService._internal() {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  }

  factory NotificationService() {
    return _instance;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInitializationSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );
    
    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'habitera_reminders',
      'Habit Reminders',
      description: 'Daily reminders for your habits',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    _isInitialized = true;
    debugPrint('NotificationService initialized');
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final androidImplementation = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      final enabled = await androidImplementation.areNotificationsEnabled();
      debugPrint('Notifications enabled: $enabled');
      return enabled ?? false;
    }
    return true; // Assume enabled for iOS
  }

  /// Check if exact alarms are permitted (Android 12+)
  Future<bool> canScheduleExactAlarms() async {
    final androidImplementation = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      final canSchedule = await androidImplementation.canScheduleExactNotifications();
      debugPrint('Can schedule exact alarms: $canSchedule');
      return canSchedule ?? false;
    }
    return true; // Assume allowed for iOS
  }

  /// Request all required permissions and return status
  Future<Map<String, bool>> requestPermissions() async {
    bool notificationGranted = false;
    bool exactAlarmGranted = false;
    
    // Request iOS permissions
    final iosResult = await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    
    if (iosResult != null) {
      notificationGranted = iosResult;
    }
    
    // Request Android 13+ notification permission
    final androidImplementation = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      // Request notification permission
      final granted = await androidImplementation.requestNotificationsPermission();
      notificationGranted = granted ?? false;
      debugPrint('Notification permission granted: $notificationGranted');
      
      // Request exact alarm permission
      final exactGranted = await androidImplementation.requestExactAlarmsPermission();
      exactAlarmGranted = exactGranted ?? false;
      debugPrint('Exact alarm permission granted: $exactAlarmGranted');
    }
    
    return {
      'notifications': notificationGranted,
      'exactAlarms': exactAlarmGranted,
    };
  }

  Future<void> scheduleReminder(Habit habit) async {
    if (habit.reminderTime == null) {
      debugPrint('No reminder time set for habit: ${habit.title}');
      return;
    }

    try {
      // First, cancel any existing reminder for this habit
      await _flutterLocalNotificationsPlugin.cancel(habit.id.hashCode);
      
      final parts = habit.reminderTime!.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      // Schedule for today at specified time
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If time has already passed, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
      
      debugPrint('=== SCHEDULING REMINDER ===');
      debugPrint('Habit: ${habit.title}');
      debugPrint('Reminder Time: ${habit.reminderTime}');
      debugPrint('Current Time: $now');
      debugPrint('Scheduled For: $scheduledDate');
      debugPrint('Timezone: ${tz.local.name}');
      debugPrint('Notification ID: ${habit.id.hashCode}');

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        habit.id.hashCode,
        '⏰ Time for your habit!',
        '${habit.icon ?? ''} ${habit.title}',
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'habitera_reminders',
            'Habit Reminders',
            channelDescription: 'Daily reminders for your habits',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
            styleInformation: BigTextStyleInformation(
              'Don\'t forget to complete: ${habit.title}',
              contentTitle: '⏰ Habit Reminder',
              summaryText: habit.title,
            ),
          ),
          iOS: const DarwinNotificationDetails(
            sound: 'default.caf',
            badgeNumber: 1,
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      
      // Verify the notification was scheduled
      final pendingNotifications = await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
      final isScheduled = pendingNotifications.any((n) => n.id == habit.id.hashCode);
      debugPrint('Reminder scheduled successfully: $isScheduled');
      debugPrint('Total pending notifications: ${pendingNotifications.length}');
      debugPrint('===========================');
    } catch (e) {
      debugPrint('Error scheduling reminder: $e');
    }
  }

  /// Reschedule all reminders for habits with reminder times
  /// Call this on app startup to ensure reminders persist after device restart
  Future<void> rescheduleAllReminders(List<Habit> habits) async {
    debugPrint('=== RESCHEDULING ALL REMINDERS ===');
    int count = 0;
    for (final habit in habits) {
      if (habit.reminderTime != null && habit.archivedAt == null) {
        await scheduleReminder(habit);
        count++;
      }
    }
    debugPrint('Rescheduled $count reminders');
    debugPrint('==================================');
  }

  Future<void> cancelReminder(String habitId) async {
    await _flutterLocalNotificationsPlugin.cancel(habitId.hashCode);
    debugPrint('Cancelled reminder for habit: $habitId');
  }

  Future<void> cancelAllReminders() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    debugPrint('Cancelled all reminders');
  }

  /// Send a test notification immediately to verify notifications are working
  Future<void> sendTestNotification() async {
    debugPrint('Sending test notification...');
    
    await _flutterLocalNotificationsPlugin.show(
      0,
      '🎉 Notifications Working!',
      'Habitera notifications are set up correctly.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'habitera_reminders',
          'Habit Reminders',
          channelDescription: 'Daily reminders for your habits',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
    
    debugPrint('Test notification sent!');
  }

  /// Test scheduled notification - fires in 1 minute
  /// Returns a map with debug info
  Future<Map<String, dynamic>> sendTestScheduledNotification() async {
    debugPrint('Scheduling test notification for 1 minute from now...');
    
    final result = <String, dynamic>{};
    
    final now = tz.TZDateTime.now(tz.local);
    final scheduledTime = now.add(const Duration(minutes: 1));
    
    result['currentTime'] = now.toString();
    result['scheduledFor'] = scheduledTime.toString();
    result['timezone'] = tz.local.name;
    
    debugPrint('Current time: $now');
    debugPrint('Scheduled for: $scheduledTime');
    debugPrint('Timezone: ${tz.local.name}');
    
    try {
      // Cancel any previous test notification
      await _flutterLocalNotificationsPlugin.cancel(99999);
      
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        99999, // unique test ID
        '⏰ Scheduled Test!',
        'This notification was scheduled 1 minute ago.',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'habitera_reminders',
            'Habit Reminders',
            channelDescription: 'Daily reminders for your habits',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      
      // Verify it was scheduled
      final pending = await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
      final isScheduled = pending.any((n) => n.id == 99999);
      result['scheduled'] = isScheduled;
      result['totalPending'] = pending.length;
      result['error'] = null;
      
      debugPrint('Test scheduled notification created: $isScheduled');
      debugPrint('Total pending: ${pending.length}');
    } catch (e) {
      debugPrint('Error scheduling test notification: $e');
      result['scheduled'] = false;
      result['error'] = e.toString();
    }
    
    return result;
  }

  /// Get list of pending notifications for debugging
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    final pending = await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
    debugPrint('Pending notifications: ${pending.length}');
    for (var n in pending) {
      debugPrint('  - ID: ${n.id}, Title: ${n.title}, Body: ${n.body}');
    }
    return pending;
  }

  Future<void> showNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'habitera_reminders',
      'Habit Reminders',
      channelDescription: 'Daily reminders for your habits',
      importance: Importance.max,
      priority: Priority.max,
    );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  Future<void> snoozeNotification({
    required String habitId,
    required String habitTitle,
    int minutesToSnooze = 10,
  }) async {
    final snoozeTime = DateTime.now().add(Duration(minutes: minutesToSnooze));

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      habitId.hashCode + 1,
      'Habit reminder',
      habitTitle,
      tz.TZDateTime.from(snoozeTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'habitera_reminders',
          'Habit Reminders',
          channelDescription: 'Daily reminders for your habits',
          importance: Importance.max,
          priority: Priority.max,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
