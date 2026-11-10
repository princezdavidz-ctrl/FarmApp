import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'feed_schedule_local_data_source.dart';

class FeedReminderPermissionDenied implements Exception {
  const FeedReminderPermissionDenied();

  @override
  String toString() => 'Notification permission was not granted.';
}

class FeedReminderService {
  FeedReminderService({FlutterLocalNotificationsPlugin? notifications})
    : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static const supportedSounds = {'default', 'chime', 'alert', 'silent'};

  final FlutterLocalNotificationsPlugin _notifications;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null ||
          await android.requestNotificationsPermission() != true) {
        return false;
      }
      if (await android.canScheduleExactNotifications() == true) return true;
      await android.requestExactAlarmsPermission();
      return await android.canScheduleExactNotifications() == true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  Future<void> sync(
    List<FeedScheduleEntry> entries, {
    String sound = 'default',
    bool enabled = true,
  }) async {
    if (!supportedSounds.contains(sound)) {
      throw ArgumentError.value(
        sound,
        'sound',
        'Unsupported notification sound',
      );
    }
    await initialize();
    final pending = await _notifications.pendingNotificationRequests();
    for (final notification in pending.where(
      (item) => item.payload?.startsWith('feed-reminder:') ?? false,
    )) {
      await _notifications.cancel(id: notification.id);
    }

    final active = entries
        .where((entry) => enabled && entry.remindersEnabled)
        .toList(growable: false);
    if (active.length > 20) {
      throw StateError('A maximum of 20 feeding reminders can be enabled.');
    }
    final now = tz.TZDateTime.now(tz.local);
    for (var index = 0; index < active.length; index++) {
      final entry = active[index];
      var firstTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        entry.hour,
        entry.minute,
      );
      if (!firstTime.isAfter(now)) {
        firstTime = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day + 1,
          entry.hour,
          entry.minute,
        );
      }
      await _notifications.zonedSchedule(
        id: 23000 + index,
        title: 'Feeding reminder',
        body: '${entry.name} is scheduled now.',
        scheduledDate: firstTime,
        notificationDetails: notificationDetailsForSound(sound),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'feed-reminder:${entry.id}',
      );
    }
  }

  Future<void> cancelFeedReminders() async {
    await initialize();
    final pending = await _notifications.pendingNotificationRequests();
    for (final notification in pending.where(
      (item) => item.payload?.startsWith('feed-reminder:') ?? false,
    )) {
      await _notifications.cancel(id: notification.id);
    }
  }

  @visibleForTesting
  static NotificationDetails notificationDetailsForSound(String sound) {
    if (!supportedSounds.contains(sound)) {
      throw ArgumentError.value(
        sound,
        'sound',
        'Unsupported notification sound',
      );
    }
    final AndroidNotificationSound? androidSound = switch (sound) {
      'chime' => const RawResourceAndroidNotificationSound('feed_chime'),
      'alert' => const RawResourceAndroidNotificationSound('feed_alert'),
      _ => null,
    };
    final String? iOSSound = switch (sound) {
      'default' => 'default',
      'chime' => 'feed_chime.wav',
      'alert' => 'feed_alert.wav',
      _ => null,
    };
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'feed_schedule_reminders_$sound',
        'Feeding schedule',
        channelDescription: 'Reminders for your scheduled feeding times.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: sound != 'silent',
        sound: androidSound,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentSound: sound != 'silent',
        sound: iOSSound,
      ),
    );
  }
}
