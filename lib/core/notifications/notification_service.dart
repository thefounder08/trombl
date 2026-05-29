import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Trom's notification system — drives daily habit + retention.
///
/// Two notification types:
///  1. Daily vibe check  — fixed time (8 PM) every day → "what's the move?"
///  2. Morning nudge     — fixed time (10 AM) every day → "new day, new vibe"
///
/// Permission is requested on first call to [init] and is NOT awaited by the
/// caller, so it never blocks the app startup flow.
class NotificationService {
  NotificationService._();
  static final _instance = NotificationService._();
  factory NotificationService() => _instance;

  static const _channelId   = 'trombl_main';
  static const _channelName = 'trombl nudges';
  static const _channelDesc = 'daily reminders from trom, ur chaotic bestie';

  // Notification IDs — must be stable so rescheduling replaces instead of stacks.
  static const _idMorning   = 1001;
  static const _idEvening   = 1002;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  /// Call once at app start (from main or after auth).
  Future<void> init() async {
    if (_initialised) return;
    tz_data.initializeTimeZones();
    // Best-effort: set to Asia/Kolkata; works for both Indian users and others.
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (_) {
      // If timezone data isn't available, fall back to UTC
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings  = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
    );

    _initialised = true;
  }

  /// Request permission (Android 13+, iOS). Call after user opts in.
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true, badge: true, sound: true,
      );
      return granted ?? false;
    }
    return false;
  }

  /// Schedule both daily notifications. Safe to call multiple times — cancels
  /// existing ones first so they don't stack.
  Future<void> scheduleDailyReminders() async {
    if (!_initialised) await init();

    await _plugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);

    // ── Morning nudge: 10:00 AM daily ────────────────────────────────────────
    await _scheduleDaily(
      id: _idMorning,
      hour: 10, minute: 0,
      title: _pick(_morningTitles),
      body: _pick(_morningBodies),
      now: now,
    );

    // ── Evening vibe check: 8:00 PM daily ────────────────────────────────────
    await _scheduleDaily(
      id: _idEvening,
      hour: 20, minute: 0,
      title: _pick(_eveningTitles),
      body: _pick(_eveningBodies),
      now: now,
    );
  }

  /// Cancel all trom notifications (e.g. user signs out).
  Future<void> cancelAll() => _plugin.cancelAll();

  // ─── Internal ────────────────────────────────────────────────────────────────

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required tz.TZDateTime now,
  }) async {
    var scheduled = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, hour, minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFFF2B705), // fomo gold
          enableVibration: true,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
      // Use inexact — no SCHEDULE_EXACT_ALARM permission needed (Android 12+)
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
    );
  }

  String _pick(List<String> list) {
    final mutable = List<String>.from(list);
    mutable.shuffle();
    return mutable.first;
  }

  // ─── Copy ─────────────────────────────────────────────────────────────────────

  static const _morningTitles = [
    "new day incoming 🔥",
    "it's a new day.",
    "trom is awake. are u?",
    "fresh start, same you.",
    "morning. what's the vibe?",
  ];

  static const _morningBodies = [
    "fomo or jomo today? one tap decides.",
    "ur bestie needs to know the plan.",
    "pick ur vibe before the day picks for u.",
    "trom has ideas. open up.",
    "every great day starts with a vibe check.",
  ];

  static const _eveningTitles = [
    "what's the move tonight? 👀",
    "evening check-in with trom.",
    "don't let the night go to waste.",
    "ok it's evening. fomo or jomo?",
    "trom's wondering what ur doing.",
  ];

  static const _eveningBodies = [
    "ur night is still yours. let's decide.",
    "five seconds to pick. ready?",
    "whether u go out or rot in — trom's here.",
    "the night doesn't plan itself.",
    "one tap. that's all ur commitment right now.",
  ];
}
