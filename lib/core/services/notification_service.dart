import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Service for managing local notifications
class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Notification channel IDs
  static const String devotionalChannelId = 'devotional_reminders';
  static const String devotionalChannelName = 'Daily Devotional';
  static const String devotionalChannelDesc = 'Reminders for your daily devotional';

  // Notification IDs
  static const int devotionalNotificationId = 1;

  /// Initialize the notification service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Initialize timezone
      tz_data.initializeTimeZones();

      // Android settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS settings
      final iosSettings = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      // Linux settings
      final linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open Hamorah',
      );

      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
        linux: linuxSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channel for Android
      if (Platform.isAndroid) {
        await _createAndroidChannel();
      }

      _isInitialized = true;
      debugPrint('NotificationService initialized');
      return true;
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
      return false;
    }
  }

  Future<void> _createAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      devotionalChannelId,
      devotionalChannelName,
      description: devotionalChannelDesc,
      importance: Importance.defaultImportance,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle notification tap - navigate to devotional screen
    // This would typically be handled via a callback or navigation service
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    }

    if (Platform.isAndroid) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return result ?? false;
    }

    return true;
  }

  /// Schedule daily devotional reminder
  Future<void> scheduleDailyDevotional({
    required int hour,
    required int minute,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Cancel any existing devotional notifications
    await cancelDevotionalReminder();

    // Get the local timezone
    final location = tz.local;

    // Calculate the next occurrence
    final now = tz.TZDateTime.now(location);
    var scheduledDate = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      devotionalNotificationId,
      'Time for Your Daily Devotional',
      'Start your day with Scripture and reflection',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          devotionalChannelId,
          devotionalChannelName,
          channelDescription: devotionalChannelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      payload: 'devotional',
    );

    debugPrint('Scheduled daily devotional for $hour:$minute');
  }

  /// Cancel devotional reminder
  Future<void> cancelDevotionalReminder() async {
    await _notifications.cancel(devotionalNotificationId);
    debugPrint('Cancelled devotional reminder');
  }

  /// Show an immediate notification (for testing)
  Future<void> showTestNotification() async {
    if (!_isInitialized) {
      await initialize();
    }

    await _notifications.show(
      999,
      'Test Notification',
      'This is a test notification from Hamorah',
      NotificationDetails(
        android: AndroidNotificationDetails(
          devotionalChannelId,
          devotionalChannelName,
          channelDescription: devotionalChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
      return result ?? false;
    }
    // For iOS/macOS, we assume enabled if initialized
    return _isInitialized;
  }
}
