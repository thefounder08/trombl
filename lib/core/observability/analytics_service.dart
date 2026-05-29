import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around Firebase Analytics.
///
/// All calls are safe before Firebase is initialised — they log to console
/// and no-op so nothing crashes during development without config files.
///
/// Event naming follows snake_case, matching Firebase conventions.
abstract final class AnalyticsService {
  static bool _ready = false;
  static FirebaseAnalytics? _analytics;

  /// Call once after Firebase.initializeApp() succeeds.
  static void init() {
    try {
      _analytics = FirebaseAnalytics.instance;
      // Disable in debug so test events don't pollute production data.
      _analytics!.setAnalyticsCollectionEnabled(!kDebugMode);
      _ready = true;
      debugPrint('[Analytics] initialised (collection: ${!kDebugMode})');
    } catch (e) {
      debugPrint('[Analytics] init skipped: $e');
    }
  }

  // ─── User ────────────────────────────────────────────────────────────────

  static void setUser(String userId) {
    _log('set_user', {'user_id': userId});
    if (!_ready) return;
    try { _analytics!.setUserId(id: userId); } catch (_) {}
  }

  static void clearUser() {
    if (!_ready) return;
    try { _analytics!.setUserId(id: null); } catch (_) {}
  }

  // ─── Onboarding ──────────────────────────────────────────────────────────

  /// User completed magic-link sign-in.
  static void loginCompleted({required String method}) =>
      _event('login', {'method': method});

  /// New user finished the name-setup screen.
  static void onboardingCompleted() => _event('onboarding_completed');

  // ─── Core flow ───────────────────────────────────────────────────────────

  /// User picked fomo or jomo for the day.
  static void vibePicked({required String vibe}) =>
      _event('vibe_picked', {'vibe': vibe});

  /// User opened a category on the menu grid.
  static void categoryOpened({required String categoryId, required String vibe}) =>
      _event('category_opened', {'category_id': categoryId, 'vibe': vibe});

  /// User tapped a real option (not coming-soon) → navigated to response.
  static void optionSelected({
    required String categoryId,
    required String optionId,
    required String tag,
    required String vibe,
  }) =>
      _event('option_selected', {
        'category_id': categoryId,
        'option_id': optionId,
        'tag': tag,
        'vibe': vibe,
      });

  /// User tapped a coming-soon option (shows toast).
  static void comingSoonTapped({required String optionId}) =>
      _event('coming_soon_tapped', {'option_id': optionId});

  // ─── Response screen ─────────────────────────────────────────────────────

  /// LLM reaction loaded successfully on the response screen.
  static void reactionLoaded({required String vibe, required String tag}) =>
      _event('reaction_loaded', {'vibe': vibe, 'tag': tag});

  /// User tapped the primary action button (WhatsApp, Zomato, etc.).
  static void actionLaunched({
    required String tag,
    required String result, // "launched" | "dnd_internal" | "failed"
  }) =>
      _event('action_launched', {'tag': tag, 'result': result});

  /// User entered the DND screen.
  static void dndEntered() => _event('dnd_entered');

  // ─── Check-in + summary ──────────────────────────────────────────────────

  /// User tapped "wrap up" to start check-in.
  static void checkinStarted({required int pickCount}) =>
      _event('checkin_started', {'pick_count': pickCount});

  /// User wrapped the day — session complete.
  static void sessionWrapped({
    required String vibe,
    required int totalPicks,
    required int donePicks,
  }) =>
      _event('session_wrapped', {
        'vibe': vibe,
        'total_picks': totalPicks,
        'done_picks': donePicks,
        'completion_rate': totalPicks > 0 ? (donePicks / totalPicks * 100).round() : 0,
      });

  /// "new vibe" tapped from summary (user resets for a new session).
  static void newVibeStarted() => _event('new_vibe_started');

  // ─── Plans ───────────────────────────────────────────────────────────────

  /// User created a new plan.
  static void planCreated({required String vibe}) =>
      _event('plan_created', {'vibe': vibe});

  /// User responded to a plan invite (i'm in / can't tonight).
  static void planJoined({required String status}) =>
      _event('plan_joined', {'status': status}); // status: "in" | "out"

  // ─── Profile ─────────────────────────────────────────────────────────────

  /// Profile screen opened.
  static void profileOpened() => _event('profile_opened');

  // ─── Notifications ───────────────────────────────────────────────────────

  /// User granted notification permission.
  static void notificationPermissionGranted() =>
      _event('notification_permission_granted');

  // ─── Internal ────────────────────────────────────────────────────────────

  static void _event(String name, [Map<String, Object>? params]) {
    _log(name, params);
    if (!_ready) return;
    try {
      _analytics!.logEvent(
        name: name,
        parameters: params?.map((k, v) => MapEntry(k, v)),
      );
    } catch (e) {
      debugPrint('[Analytics] event error: $e');
    }
  }

  static void _log(String name, [Map<String, Object?>? params]) {
    if (kDebugMode) {
      debugPrint('[Analytics] $name${params != null ? ' $params' : ''}');
    }
  }
}
