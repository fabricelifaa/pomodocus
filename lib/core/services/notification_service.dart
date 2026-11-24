import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

enum NotificationPermission { granted, denied, unknown }

/// Abstraction so the timer never depends on a specific notification plugin.
abstract interface class NotificationService {
  Future<void> init();

  Future<NotificationPermission> permissionStatus();

  /// Asks the OS for permission. Returns the resulting status.
  Future<NotificationPermission> requestPermission();

  /// Schedules the end-of-session notification. Never throws: a failure here
  /// must never lose the active session.
  Future<void> scheduleSessionEnd({
    required DateTime at,
    required String title,
    required String body,
    required bool withSound,
    required bool withVibration,
  });

  Future<void> cancelSessionEnd();
}

class LocalNotificationService implements NotificationService {
  LocalNotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _sessionEndId = 1001;
  // Android channels are immutable once created: one per sound/vibration
  // combination so that the user's preferences are honoured.
  static const _channelPrefix = 'session_end';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_pomodocus'),
          // Permission is requested later, in context, not at launch.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  @override
  Future<NotificationPermission> permissionStatus() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final enabled = await _android?.areNotificationsEnabled();
        if (enabled == null) return NotificationPermission.unknown;
        return enabled
            ? NotificationPermission.granted
            : NotificationPermission.denied;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final opts = await _ios?.checkPermissions();
        if (opts == null) return NotificationPermission.unknown;
        return opts.isEnabled
            ? NotificationPermission.granted
            : NotificationPermission.denied;
      }
    } catch (_) {}
    return NotificationPermission.unknown;
  }

  @override
  Future<NotificationPermission> requestPermission() async {
    try {
      bool? granted;
      if (defaultTargetPlatform == TargetPlatform.android) {
        granted = await _android?.requestNotificationsPermission();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        granted = await _ios?.requestPermissions(
          alert: true,
          sound: true,
          badge: false,
        );
      }
      if (granted == null) return NotificationPermission.unknown;
      return granted
          ? NotificationPermission.granted
          : NotificationPermission.denied;
    } catch (_) {
      return NotificationPermission.unknown;
    }
  }

  @override
  Future<void> scheduleSessionEnd({
    required DateTime at,
    required String title,
    required String body,
    required bool withSound,
    required bool withVibration,
  }) async {
    if (!_ready) await init();
    try {
      await cancelSessionEnd();
      final channelId =
          '${_channelPrefix}_${withSound ? 's' : 'n'}${withVibration ? 'v' : 'n'}';
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Fin de session',
          channelDescription:
              'Prévient quand une concentration ou une pause se termine.',
          importance: Importance.high,
          priority: Priority.high,
          playSound: withSound,
          enableVibration: withVibration,
          category: AndroidNotificationCategory.alarm,
          color: const Color(0xFFF2553D),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: withSound,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );
      final when = tz.TZDateTime.from(at.toUtc(), tz.UTC);
      // Exact alarms when the user/OS allows it, otherwise inexact (may be
      // delayed by Doze on Android).
      var mode = AndroidScheduleMode.inexactAllowWhileIdle;
      if (defaultTargetPlatform == TargetPlatform.android) {
        final exact = await _android?.canScheduleExactNotifications() ?? false;
        if (exact) mode = AndroidScheduleMode.exactAllowWhileIdle;
      }
      await _plugin.zonedSchedule(
        id: _sessionEndId,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: mode,
        title: title,
        body: body,
      );
    } catch (e) {
      debugPrint('Scheduling notification failed: $e');
    }
  }

  @override
  Future<void> cancelSessionEnd() async {
    try {
      await _plugin.cancel(id: _sessionEndId);
    } catch (_) {}
  }
}

/// No-op implementation for tests and unsupported platforms.
class NoopNotificationService implements NotificationService {
  NotificationPermission status = NotificationPermission.granted;
  final scheduled = <DateTime>[];
  int cancelCount = 0;

  @override
  Future<void> init() async {}

  @override
  Future<NotificationPermission> permissionStatus() async => status;

  @override
  Future<NotificationPermission> requestPermission() async => status;

  @override
  Future<void> scheduleSessionEnd({
    required DateTime at,
    required String title,
    required String body,
    required bool withSound,
    required bool withVibration,
  }) async => scheduled.add(at);

  @override
  Future<void> cancelSessionEnd() async => cancelCount++;
}
