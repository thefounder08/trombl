import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Wraps Firebase Crashlytics with graceful fallback.
///
/// All methods are safe to call before Firebase is initialised (e.g. when
/// google-services.json / GoogleService-Info.plist are absent during dev).
/// Errors are logged to the console instead.
abstract final class CrashService {
  static bool _ready = false;

  /// Call once after Firebase.initializeApp() succeeds.
  static void init() {
    try {
      // In debug: send reports to console, not Crashlytics, to avoid noise.
      FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

      // Wire Flutter framework errors → Crashlytics.
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        // Always call the original handler first (shows red-screen in debug).
        originalOnError?.call(details);
        if (!kDebugMode) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        } else {
          debugPrint('[Crash] Flutter error: ${details.exceptionAsString()}');
        }
      };

      _ready = true;
      debugPrint('[Crash] Crashlytics initialised (collection: ${!kDebugMode})');
    } catch (e) {
      debugPrint('[Crash] Crashlytics init skipped: $e');
    }
  }

  /// Wire into runZonedGuarded to catch unhandled async errors.
  static void onAsyncError(Object error, StackTrace stack) {
    debugPrint('[Crash] async error: $error');
    if (_ready && !kDebugMode) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  }

  /// Record a non-fatal error (e.g. repository failure, LLM timeout).
  static void recordError(Object error, StackTrace? stack, {String? reason}) {
    debugPrint('[Crash] non-fatal: $error${reason != null ? ' ($reason)' : ''}');
    if (_ready && !kDebugMode) {
      FirebaseCrashlytics.instance.recordError(
        error, stack,
        reason: reason,
        fatal: false,
      );
    }
  }

  /// Attach user identity to crash reports after sign-in.
  static void setUser(String userId) {
    if (!_ready) return;
    try {
      FirebaseCrashlytics.instance.setUserIdentifier(userId);
    } catch (_) {}
  }

  /// Clear user on sign-out.
  static void clearUser() {
    if (!_ready) return;
    try {
      FirebaseCrashlytics.instance.setUserIdentifier('');
    } catch (_) {}
  }
}
