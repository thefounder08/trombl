import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../identity/guest_identity_service.dart';
import 'analytics_event.dart';
import 'analytics_service.dart';
import 'crash_service.dart';

const _sessionPrefsKey = 'trombl_analytics_session_v1';

/// The single front door for all analytics in the app — **no screen or
/// provider should import `AnalyticsService` or `firebase_analytics`
/// directly.** This is what gets injected via Riverpod
/// (`analyticsRepositoryProvider`) and called from everywhere else.
///
/// Responsibilities:
/// - Merges every event with the common parameter set (guest_id, user_type,
///   platform, app_version, build_number, device_language, timezone,
///   timestamp, current_screen, previous_screen) exactly once per call,
///   so no call site has to remember to attach context.
/// - Tracks a lightweight local session (start/end, event/AI-call/option
///   counters, vibe) and persists it to SharedPreferences so a kill/crash
///   mid-session can still be recovered and flushed as `session_ended` on
///   the next launch — "store locally until uploaded" without pulling in
///   a full local database for what's fundamentally a handful of counters.
/// - Pretty-prints every event to the console in debug builds.
/// - Keeps Crashlytics' user context (guest_id/user_type/screen/session_id)
///   in sync so every crash report is already filterable by those fields.
class AnalyticsRepository {
  AnalyticsRepository(this._identity);

  final GuestIdentityService _identity;

  bool _initialized = false;
  late String _platform;
  late String _appVersion;
  late String _buildNumber;
  late String _deviceLanguage;
  late String _timezone;

  String? _currentScreen;
  String? _previousScreen;
  DateTime? _screenEnteredAt;

  String? _sessionId;
  DateTime? _sessionStartedAt;
  int _eventCount = 0;
  int _aiCalls = 0;
  int _optionsSelected = 0;
  String? _sessionVibe;

  /// Call once at app boot (after the guest identity bootstrap), before any
  /// events are tracked. Cheap and safe to call more than once.
  Future<void> init() async {
    if (_initialized) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
      _buildNumber = info.buildNumber;
    } catch (_) {
      _appVersion = 'unknown';
      _buildNumber = 'unknown';
    }
    _platform = _resolvePlatform();
    _deviceLanguage = _resolveDeviceLanguage();
    _timezone = DateTime.now().timeZoneName;
    _initialized = true;

    // Recover a session that never got a clean session_ended (app was
    // killed, crashed, or backgrounded past the OS's grace period).
    await _recoverDanglingSession();
  }

  // ─── Session lifecycle ───────────────────────────────────────────────────

  /// True once a session has been cleanly ended (or never started) — used
  /// by [AnalyticsSessionController] to know whether resuming from the
  /// background needs a fresh `startSession()` or just a foreground ping.
  bool get hasEndedSession => _sessionId == null;

  Future<void> startSession() async {
    _sessionId = '${DateTime.now().millisecondsSinceEpoch}-${_identity.currentId ?? 'anon'}';
    _sessionStartedAt = DateTime.now();
    _eventCount = 0;
    _aiCalls = 0;
    _optionsSelected = 0;
    _sessionVibe = null;
    _syncCrashContext();
    await _persistSessionState();
    track(AnalyticsEvents.sessionStarted);
  }

  Future<void> endSession() async {
    if (_sessionId == null || _sessionStartedAt == null) return;
    final durationMs = DateTime.now().difference(_sessionStartedAt!).inMilliseconds;
    track(AnalyticsEvents.sessionEnded, {
      'session_duration_ms': durationMs,
      'number_of_events': _eventCount,
      'ai_calls': _aiCalls,
      'options_selected': _optionsSelected,
      'vibe': _sessionVibe,
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionPrefsKey);
    _sessionId = null;
    _sessionStartedAt = null;
  }

  Future<void> _recoverDanglingSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionPrefsKey);
    if (raw == null) return;
    try {
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      track('session_ended_recovered', {
        'session_id': saved['session_id'],
        'started_at': saved['started_at'],
        'number_of_events': saved['event_count'],
        'ai_calls': saved['ai_calls'],
        'options_selected': saved['options_selected'],
        'vibe': saved['vibe'],
      });
    } catch (e) {
      debugPrint('[Analytics] failed to recover dangling session: $e');
    } finally {
      await prefs.remove(_sessionPrefsKey);
    }
  }

  Future<void> _persistSessionState() async {
    if (_sessionId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionPrefsKey, jsonEncode({
      'session_id': _sessionId,
      'started_at': _sessionStartedAt?.toIso8601String(),
      'event_count': _eventCount,
      'ai_calls': _aiCalls,
      'options_selected': _optionsSelected,
      'vibe': _sessionVibe,
    }));
  }

  // ─── Screen tracking (called by AnalyticsRouteObserver) ─────────────────

  void trackScreenView({
    required String screenName,
    required String screenClass,
  }) {
    final now = DateTime.now();
    final timeSpentMs = _screenEnteredAt == null
        ? null
        : now.difference(_screenEnteredAt!).inMilliseconds;
    final previous = _currentScreen;

    AnalyticsService.setCurrentScreen(screenName, screenClass);

    _trackInternal(AnalyticsEvents.screenView, {
      'screen_name': screenName,
      'screen_class': screenClass,
      'time_spent_ms': timeSpentMs,
    }, previous);

    _previousScreen = previous;
    _currentScreen = screenName;
    _screenEnteredAt = now;
    _syncCrashContext();
  }

  // ─── Core ─────────────────────────────────────────────────────────────────

  /// The single method every `track*` helper below funnels through. Public
  /// so call sites with a one-off event name can still go through the
  /// shared base-parameter logic instead of hand-rolling it.
  void track(String name, [Map<String, Object?>? params]) {
    _trackInternal(name, params);
  }

  void _trackInternal(String name, Map<String, Object?>? params, [String? overridePreviousScreen]) {
    _eventCount++;
    final merged = <String, Object?>{
      'guest_id': _identity.currentId,
      'user_type': _identity.userType,
      'platform': _platform,
      'app_version': _appVersion,
      'build_number': _buildNumber,
      'device_language': _deviceLanguage,
      'timezone': _timezone,
      'current_screen': _currentScreen,
      'previous_screen': overridePreviousScreen ?? _previousScreen,
      'session_id': _sessionId,
      ...?params,
    };
    final event = AnalyticsEvent(name: name, params: merged);

    AnalyticsService.logEvent(event);
    _persistSessionState();
    _debugPrint(event);
  }

  void _debugPrint(AnalyticsEvent event) {
    if (!kDebugMode) return;
    debugPrint('📊 Event');
    debugPrint('event: ${event.name}');
    debugPrint('parameters:');
    event.params.forEach((k, v) {
      if (v != null) debugPrint('  $k: $v');
    });
  }

  // ─── App lifecycle ──────────────────────────────────────────────────────

  void trackAppOpened() => track(AnalyticsEvents.appOpened);
  void trackAppForeground() => track(AnalyticsEvents.appForeground);
  void trackAppBackground() => track(AnalyticsEvents.appBackground);
  void trackSessionEnded() => endSession();

  // ─── Tutorial ───────────────────────────────────────────────────────────

  void trackTutorialStarted() => track(AnalyticsEvents.tutorialStarted);
  void trackTutorialCompleted() => track(AnalyticsEvents.tutorialCompleted);
  void trackTutorialSkipped({int? atSlide}) =>
      track(AnalyticsEvents.tutorialSkipped, {'at_slide': atSlide});

  // ─── Onboarding ─────────────────────────────────────────────────────────

  void trackOnboardingStarted() => track(AnalyticsEvents.onboardingStarted);
  void trackOnboardingCompleted() => track(AnalyticsEvents.onboardingCompleted);

  // ─── Core loop ──────────────────────────────────────────────────────────

  void trackVibeSelected(String vibe) {
    _sessionVibe = vibe;
    track(AnalyticsEvents.vibeSelected, {'vibe': vibe});
  }

  void trackCategoryOpened({required String categoryId, required String vibe}) =>
      track(AnalyticsEvents.categoryOpened, {'category_id': categoryId, 'vibe': vibe});

  void trackOptionSelected({
    required String categoryId,
    required String optionId,
    required String tag,
    required String vibe,
  }) {
    _optionsSelected++;
    track(AnalyticsEvents.optionSelected, {
      'category_id': categoryId,
      'option_id': optionId,
      'tag': tag,
      'vibe': vibe,
    });
  }

  void trackComingSoonTapped({required String optionId}) =>
      track(AnalyticsEvents.comingSoonTapped, {'option_id': optionId});

  // ─── AI decide ──────────────────────────────────────────────────────────

  void trackAIDecideStarted() {
    _aiCalls++;
    track(AnalyticsEvents.aiDecideStarted);
  }

  void trackAIDecideCompleted({required bool fromFallback, int? rerollCount}) =>
      track(AnalyticsEvents.aiDecideCompleted, {
        'from_fallback': fromFallback,
        'reroll_count': rerollCount,
      });

  void trackAIReroll({required int rerollCount}) =>
      track(AnalyticsEvents.aiReroll, {'reroll_count': rerollCount});

  void trackAIAccepted({String? tag}) =>
      track(AnalyticsEvents.aiAccepted, {'tag': tag});

  // ─── Response / action ──────────────────────────────────────────────────

  void trackReactionLoaded({required String vibe, required String tag}) =>
      track(AnalyticsEvents.reactionLoaded, {'vibe': vibe, 'tag': tag});

  void trackActionLaunched({required String tag, required String result}) =>
      track(AnalyticsEvents.actionLaunched, {'tag': tag, 'result': result});

  void trackDndEntered() => track(AnalyticsEvents.dndEntered);

  void trackShareClicked({required String surface}) =>
      track(AnalyticsEvents.shareClicked, {'surface': surface});

  // ─── Check-in / summary ─────────────────────────────────────────────────

  void trackCheckinStarted({required int pickCount}) =>
      track(AnalyticsEvents.checkinStarted, {'pick_count': pickCount});

  void trackCheckinCompleted({required int totalPicks, required int donePicks}) =>
      track(AnalyticsEvents.checkinCompleted, {
        'total_picks': totalPicks,
        'done_picks': donePicks,
        'completion_rate': totalPicks > 0 ? (donePicks / totalPicks * 100).round() : 0,
      });

  void trackSummaryViewed({required int totalPicks, required int donePicks}) =>
      track(AnalyticsEvents.summaryViewed, {'total_picks': totalPicks, 'done_picks': donePicks});

  void trackNewVibeStarted() => track(AnalyticsEvents.newVibeStarted);

  // ─── Plans ──────────────────────────────────────────────────────────────

  void trackPlanCreated({required String vibe}) =>
      track(AnalyticsEvents.planCreated, {'vibe': vibe});

  void trackPlanJoined({required String status}) =>
      track(AnalyticsEvents.planJoined, {'status': status});

  // ─── Profile ────────────────────────────────────────────────────────────

  void trackProfileOpened() => track(AnalyticsEvents.profileOpened);

  // ─── Notifications ──────────────────────────────────────────────────────

  void trackNotificationPermissionGranted() =>
      track(AnalyticsEvents.notificationPermissionGranted);

  void trackNotificationPermissionDenied() =>
      track(AnalyticsEvents.notificationPermissionDenied);

  // ─── Signup / conversion ────────────────────────────────────────────────

  void trackSignupPromptShown({required String surface}) =>
      track(AnalyticsEvents.signupPromptShown, {'surface': surface});

  void trackSignupStarted() => track(AnalyticsEvents.signupStarted);

  /// Call right after a guest's session is upgraded to a permanent one.
  /// Because guest mode is backed by Supabase anonymous auth, [oldGuestId]
  /// and [newUserId] are normally identical — logged anyway for parity
  /// with funnels built around the literal field names, and so nothing
  /// breaks if anonymous->permanent linking is ever swapped for a flow
  /// that *does* change the id (e.g. a future merge-accounts feature).
  void trackSignupCompleted({required String oldGuestId, required String newUserId}) {
    track(AnalyticsEvents.signupCompleted);
    track(AnalyticsEvents.guestConverted, {
      'old_guest_id': oldGuestId,
      'new_user_id': newUserId,
    });
  }

  void trackLoginCompleted({required String method}) =>
      track(AnalyticsEvents.loginCompleted, {'method': method});

  // ─── User identity (call after every auth state change) ─────────────────

  void syncUserIdentity() {
    final id = _identity.currentId;
    if (id != null) AnalyticsService.setUser(id);
    AnalyticsService.setUserProperty('user_type', _identity.userType);
    AnalyticsService.setUserProperty('app_version', _initialized ? _appVersion : null);
    AnalyticsService.setUserProperty('platform', _initialized ? _platform : null);
    AnalyticsService.setUserProperty('build_number', _initialized ? _buildNumber : null);
    _syncCrashContext();
  }

  void _syncCrashContext() {
    CrashService.setContext(
      guestId: _identity.currentId,
      userType: _identity.userType,
      screen: _currentScreen,
      sessionId: _sessionId,
    );
  }

  // ─── Platform/locale helpers ────────────────────────────────────────────

  String _resolvePlatform() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name; // android / iOS / etc, no dart:io needed
  }

  String _resolveDeviceLanguage() {
    try {
      return PlatformDispatcher.instance.locale.toLanguageTag();
    } catch (_) {
      return 'unknown';
    }
  }
}
