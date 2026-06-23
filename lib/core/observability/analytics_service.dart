import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'analytics_event.dart';

/// Thin wrapper around the Firebase Analytics SDK — the *only* file in this
/// app allowed to import `firebase_analytics`. Every screen/provider tracks
/// through `AnalyticsRepository` (see analytics_repository.dart), which
/// calls [logEvent] here with fully-resolved [AnalyticsEvent]s; this class
/// has no business logic of its own beyond "talk to Firebase safely."
///
/// All calls are safe before Firebase is initialised — they no-op so
/// nothing crashes during development without config files.
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

  /// Sets the Firebase Analytics user id — used for both guest (anonymous
  /// Supabase user id) and registered users, so the *same* id carries
  /// through sign-up with zero discontinuity in the Firebase timeline.
  static void setUser(String userId) {
    if (!_ready) return;
    try {
      _analytics!.setUserId(id: userId);
    } catch (_) {}
  }

  static void clearUser() {
    if (!_ready) return;
    try {
      _analytics!.setUserId(id: null);
    } catch (_) {}
  }

  static void setUserProperty(String name, String? value) {
    if (!_ready) return;
    try {
      _analytics!.setUserProperty(name: name, value: value);
    } catch (_) {}
  }

  // ─── Events ─────────────────────────────────────────────────────────────

  /// Sends a fully-resolved event to Firebase. Does not log/print anything
  /// itself — `AnalyticsRepository` owns the debug-mode pretty-printer and
  /// the local buffer, so this stays a pure "send it" call.
  static void logEvent(AnalyticsEvent event) {
    if (!_ready) return;
    try {
      _analytics!.logEvent(
        name: event.name,
        parameters: event.toFirebaseParams(),
      );
    } catch (e) {
      debugPrint('[Analytics] event error: $e');
    }
  }

  /// Reports the current screen via Firebase's dedicated screen-view event,
  /// in addition to the generic `screen_view` event AnalyticsRepository also
  /// logs — Firebase's native screen reporting feeds the Funnels/Engagement
  /// views in the console directly.
  static void setCurrentScreen(String screenName, String screenClass) {
    if (!_ready) return;
    try {
      _analytics!.logScreenView(screenName: screenName, screenClass: screenClass);
    } catch (_) {}
  }
}
