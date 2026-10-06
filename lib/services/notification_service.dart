import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'browser_notification.dart' as browser_notification;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final Map<int, List<Timer>> _webReminderTimers = {};

  static const String channelId = 'rent_reminders';
  static const String channelName = 'Rent Reminders';
  static const String channelDescription =
      'Notifications for upcoming rent payments.';
  static const String _webPushVapidPublicKey = String.fromEnvironment(
    'WEB_PUSH_VAPID_PUBLIC_KEY',
    defaultValue: 'BKTjhparKCnlmt3vYzJrvNDJxc3yxScX3jgO66mmS8OvLR_3ZxI90-y0QNjfqShIlUcD22hiIuYHH8Y8CzPitXM',
  );

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> requestBrowserPermission() async {
    if (!kIsWeb) return true;
    return browser_notification.requestPermission();
  }

  bool get hasBrowserPushSubscription =>
      kIsWeb && browser_notification.hasPushSubscription;

  Future<Map<String, dynamic>> subscribeToBrowserPush() {
    if (!kIsWeb) {
      throw UnsupportedError(
        'Browser push notifications are only available on web.',
      );
    }
    return browser_notification.subscribeToPush(_webPushVapidPublicKey);
  }

  void markBrowserPushSubscriptionSaved() {
    if (kIsWeb) browser_notification.markPushSubscriptionSaved();
  }

  Future<void> initialize() async {
    if (!_isAndroid) {
      return;
    }

    tz.initializeTimeZones();

    tz.setLocalLocation(tz.getLocation('Africa/Nairobi'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(settings: initializationSettings);

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
      ),
    );

    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  Future<void> showTestNotification() async {
    if (kIsWeb) {
      await browser_notification.show(
        'Rent Reminder',
        'Browser notifications are working.',
      );
      return;
    }

    if (!_isAndroid) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: 999999,
      title: 'Rent Reminder',
      body: 'Your rent reminder notifications are working.',
      notificationDetails: details,
    );
  }

  Future<void> scheduleTestReminder() async {
    if (kIsWeb) {
      Timer(const Duration(minutes: 1), () {
        browser_notification.show(
          'Rent Reminder Test',
          'This is a scheduled rent reminder test.',
        );
      });
      return;
    }

    if (!_isAndroid) {
      return;
    }

    final scheduledDate = tz.TZDateTime.now(tz.local)
        .add(const Duration(minutes: 1));

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id: 999998,
      title: 'Rent Reminder Test',
      body: 'This is a scheduled rent reminder test.',
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> scheduleMonthlyReminders({
    required int baseNotificationId,
    required String propertyName,
    required String currency,
    required String rent,
    required int dueDay,
    required List<int> reminderDays,
  }) async {
    if (!_isAndroid && !kIsWeb) {
      return;
    }

    if (kIsWeb && !browser_notification.isPermissionGranted) {
      return;
    }

    if (kIsWeb && browser_notification.hasPushSubscription) {
      return;
    }

    tz.initializeTimeZones();
    final location = tz.getLocation('Africa/Nairobi');
    if (_isAndroid) {
      tz.setLocalLocation(location);
    }
    final now = tz.TZDateTime.now(location);

    for (int monthOffset = 0; monthOffset < 12; monthOffset++) {
      final rawMonth = now.month + monthOffset;

      final year = now.year + ((rawMonth - 1) ~/ 12);

      final month = ((rawMonth - 1) % 12) + 1;

      final daysInMonth = DateTime(year, month + 1, 0).day;

      final actualDueDay = dueDay > daysInMonth ? daysInMonth : dueDay;

      final dueDate = tz.TZDateTime(tz.local, year, month, actualDueDay);

      for (final daysBefore in reminderDays) {
        final reminderDate = dueDate.subtract(Duration(days: daysBefore));

        final scheduledDate = tz.TZDateTime(
          location,
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          9,
          0,
        );

        if (scheduledDate.isBefore(now)) {
          continue;
        }

        final notificationId =
            baseNotificationId + (monthOffset * 10) + daysBefore;

        String title;
        String body;

        if (daysBefore == 0) {
          title = 'Rent is due today';

          body = '$propertyName rent of $currency $rent is due today.';
        } else if (daysBefore == 1) {
          title = 'Rent due tomorrow';

          body = '$propertyName rent of $currency $rent is due tomorrow.';
        } else {
          title = 'Rent due in $daysBefore days';

          body =
              '$propertyName rent of $currency $rent is due in $daysBefore days.';
        }

        const androidDetails = AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        );

        const details = NotificationDetails(android: androidDetails);

        if (kIsWeb) {
          final timer = Timer(scheduledDate.difference(now), () {
            browser_notification.show(title, body);
          });
          _webReminderTimers
              .putIfAbsent(baseNotificationId, () => [])
              .add(timer);
        } else {
          await _plugin.zonedSchedule(
            id: notificationId,
            title: title,
            body: body,
            scheduledDate: scheduledDate,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        }
      }
    }
  }

  Future<void> cancelPropertyReminders(int baseNotificationId) async {
    if (kIsWeb) {
      for (final timer
          in _webReminderTimers.remove(baseNotificationId) ?? <Timer>[]) {
        timer.cancel();
      }
      return;
    }

    if (!_isAndroid) {
      return;
    }

    for (int month = 0; month < 12; month++) {
      for (int days = 0; days <= 7; days++) {
        final notificationId = baseNotificationId + (month * 10) + days;

        await _plugin.cancel(id: notificationId);
      }
    }
  }

  Future<void> cancelTestReminder() async {
    if (kIsWeb) {
      return;
    }

    if (!_isAndroid) {
      return;
    }

    await _plugin.cancel(id: 999998);
  }

  Future<void> cancelAll() async {
    if (kIsWeb) {
      for (final timers in _webReminderTimers.values) {
        for (final timer in timers) {
          timer.cancel();
        }
      }
      _webReminderTimers.clear();
      return;
    }

    if (!_isAndroid) {
      return;
    }

    await _plugin.cancelAll();
  }
}
