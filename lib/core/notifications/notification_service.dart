import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Top-level handler required by Firebase for background messages.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage msg) async {
  // Nothing to do here; flutter_local_notifications handles foreground display.
  debugPrint('[FCM] background message: ${msg.notification?.title}');
}

/// Trom's notification service — FCM token registration + local nudges.
///
/// Responsibilities:
///  1. Initialize Firebase Messaging and local notifications.
///  2. Request permission (Android 13+, iOS).
///  3. Fetch the FCM token and upsert it to `push_tokens` in Supabase.
///  4. Show foreground FCM messages as local notifications.
///  5. Schedule daily local nudges (10 AM morning + 8 PM evening).
class NotificationService {
  NotificationService._();
  static final _instance = NotificationService._();
  factory NotificationService() => _instance;

  static const _channelId   = 'trombl_main';
  static const _channelName = 'trombl nudges';
  static const _channelDesc = 'daily reminders from trom, ur chaotic bestie';

  static const _idMorning = 1001;
  static const _idEvening = 1002;

  final _localPlugin = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  // ─── Init ─────────────────────────────────────────────────────────────────

  /// Call once at app start. Safe to call multiple times.
  Future<void> init() async {
    if (_initialised) return;
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (_) {}

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings  = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    try {
      await _localPlugin.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
        ),
      );
    } catch (e) {
      debugPrint('[Notification] local plugin init skipped: $e');
    }

    // Wire Firebase background handler — safe-guarded so web/unconfigured
    // Firebase environments don't crash before runApp() is called.
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    } catch (e) {
      debugPrint('[Notification] Firebase Messaging not available: $e');
    }

    _initialised = true;
  }

  // ─── Permission ───────────────────────────────────────────────────────────

  /// Request notification permission. Returns true when granted.
  Future<bool> requestPermission() async {
    // iOS / Android 13+: ask Firebase first (covers both platforms)
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );
    final fcmGranted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    // Android: also request via local notifications (covers Android 12-)
    final android = _localPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    return fcmGranted;
  }

  // ─── FCM token registration ───────────────────────────────────────────────

  /// Fetch the FCM token and upsert it to `push_tokens`.
  /// Safe to call on every sign-in — uses conflict resolution on (user_id, token).
  Future<void> registerToken() async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await client.from('push_tokens').upsert({
        'user_id': client.auth.currentUser!.id,
        'token': token,
        'platform': _platform(),
      }, onConflict: 'user_id,token');

      debugPrint('[FCM] token registered: ${token.substring(0, 16)}…');

      // Refresh token on rotation
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        if (client.auth.currentUser == null) return;
        await client.from('push_tokens').upsert({
          'user_id': client.auth.currentUser!.id,
          'token': newToken,
          'platform': _platform(),
        }, onConflict: 'user_id,token');
      });
    } catch (e) {
      debugPrint('[FCM] token registration error: $e');
    }
  }

  /// Unregister all tokens for the current user on sign-out.
  Future<void> unregisterTokens() async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return;
      await client
          .from('push_tokens')
          .delete()
          .eq('user_id', client.auth.currentUser!.id);
    } catch (_) {}
  }

  // ─── Local daily nudges ───────────────────────────────────────────────────

  /// Schedule 10 AM morning + 8 PM evening repeating local nudges.
  Future<void> scheduleDailyReminders() async {
    if (!_initialised) await init();
    await _localPlugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    await _scheduleDaily(id: _idMorning, hour: 10, minute: 0,
        title: _pick(_morningTitles), body: _pick(_morningBodies), now: now);
    await _scheduleDaily(id: _idEvening, hour: 20, minute: 0,
        title: _pick(_eveningTitles), body: _pick(_eveningBodies), now: now);
  }

  Future<void> cancelAll() => _localPlugin.cancelAll();

  // ─── Private ─────────────────────────────────────────────────────────────

  Future<void> _onForegroundMessage(RemoteMessage msg) async {
    final n = msg.notification;
    if (n == null) return;
    await _localPlugin.show(
      msg.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFFF2B705),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> _scheduleDaily({
    required int id, required int hour, required int minute,
    required String title, required String body,
    required tz.TZDateTime now,
  }) async {
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _localPlugin.zonedSchedule(
      id, title, body, scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFFF2B705),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: false, presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  String _pick(List<String> list) => (List<String>.from(list)..shuffle()).first;

  String _platform() {
    // dart:io Platform is not accessible in web, so check via conditional.
    try {
      // ignore: do_not_use_environment
      const isIOS = bool.fromEnvironment('dart.library.io') &&
          !bool.fromEnvironment('dart.library.html');
      return isIOS ? 'ios' : 'android';
    } catch (_) {
      return 'android';
    }
  }

  static const _morningTitles = [
    "new day incoming 🔥", "it's a new day.", "trom is awake. are u?",
    "fresh start, same you.", "morning. what's the vibe?",
  ];
  static const _morningBodies = [
    "fomo or jomo today? one tap decides.",
    "ur bestie needs to know the plan.",
    "pick ur vibe before the day picks for u.",
    "trom has ideas. open up.",
    "every great day starts with a vibe check.",
  ];
  static const _eveningTitles = [
    "what's the move tonight? 👀", "evening check-in with trom.",
    "don't let the night go to waste.", "ok it's evening. fomo or jomo?",
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
