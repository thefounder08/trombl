import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../router/app_router.dart';
import 'notification_routing.dart';

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

    const androidSettings = AndroidInitializationSettings('@drawable/ic_stat_notify');
    const darwinSettings  = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    try {
      await _localPlugin.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
        ),
        onDidReceiveNotificationResponse: _onLocalNotificationTapped,
      );
    } catch (e) {
      debugPrint('[Notification] local plugin init skipped: $e');
    }

    // Wire Firebase background handler — safe-guarded so web/unconfigured
    // Firebase environments don't crash before runApp() is called.
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // App was backgrounded (not killed) when the push was tapped.
      FirebaseMessaging.onMessageOpenedApp.listen(_navigateForMessage);

      // App was fully killed and was launched by tapping the push.
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) _navigateForMessage(initialMessage);
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
  /// Safe to call on every sign-in — a device token belongs to exactly one
  /// user (enforced by a unique constraint on `token`), so re-registering
  /// under a different account reassigns the row instead of leaving a
  /// stale duplicate behind for the previous user.
  Future<void> registerToken() async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await _claimToken(client, token);
      debugPrint('[FCM] token registered: ${token.substring(0, 16)}…');

      // Refresh token on rotation
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        if (client.auth.currentUser == null) return;
        await _claimToken(client, newToken);
      });
    } catch (e) {
      debugPrint('[FCM] token registration error: $e');
    }
  }

  /// Upserts on the unique `token` column so a device token always maps to
  /// exactly the current user, even if it was previously owned by someone
  /// else who signed in on the same device without signing out first.
  Future<void> _claimToken(SupabaseClient client, String token) async {
    await client.from('push_tokens').upsert({
      'user_id': client.auth.currentUser!.id,
      'token': token,
      'platform': _platform(),
    }, onConflict: 'token');
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
      id: msg.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_stat_notify',
          color: Color(0xFFF2B705),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
      payload: jsonEncode({'kind': msg.data['kind'] ?? '', 'data': msg.data}),
    );
  }

  /// Tapped a locally-shown notification (i.e. a push that arrived while
  /// the app was in the foreground).
  void _onLocalNotificationTapped(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final kind = decoded['kind'] as String? ?? '';
      final data = (decoded['data'] as Map?)?.cast<String, dynamic>() ?? const {};
      _navigate(kind, data);
    } catch (e) {
      debugPrint('[Notification] payload parse failed: $e');
    }
  }

  /// Tapped a push that opened the app from background or killed state.
  void _navigateForMessage(RemoteMessage msg) {
    final kind = msg.data['kind'] ?? '';
    _navigate(kind, msg.data);
  }

  void _navigate(String kind, Map<String, dynamic> data) {
    final route = resolveNotificationRoute(kind, data);
    appRouter?.go(route);
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
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_stat_notify',
          color: Color(0xFFF2B705),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: false, presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  String _pick(List<String> list) => (List<String>.from(list)..shuffle()).first;

  String _platform() => Platform.isIOS ? 'ios' : 'android';

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
