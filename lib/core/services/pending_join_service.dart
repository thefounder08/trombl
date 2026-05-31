import 'package:shared_preferences/shared_preferences.dart';

/// Persists a pending plan-join intent across app restarts.
///
/// Used when an unauthenticated user taps "i'm in" on /p/:token — the intent
/// is saved here so that after a magic-link restart or OTP verify + name setup,
/// the plan landing screen can auto-complete the join.
class PendingJoinService {
  static const _tokenKey  = 'pending_plan_token';
  static const _statusKey = 'pending_plan_status';

  static Future<void> save(String token, String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_statusKey, status);
  }

  static Future<({String token, String status})?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token  = prefs.getString(_tokenKey);
      final status = prefs.getString(_statusKey);
      if (token == null || status == null) return null;
      return (token: token, status: status);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_statusKey);
    } catch (_) {}
  }
}
