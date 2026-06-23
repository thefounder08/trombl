import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

/// Backs "use the app without signing up" with a real Supabase **anonymous**
/// auth session instead of a locally-generated UUID.
///
/// Why not a local UUID + flutter_secure_storage (the naive approach):
/// every table in this app (sessions, picks, ai_picks, plans, memory_nodes,
/// notifications, ...) is keyed by `auth.uid()` and RLS-scoped to it. A
/// locally-generated guest id has no `auth.uid()` behind it, so a guest
/// could never write to any of those tables without rewriting every
/// repository and RLS policy to understand a second, parallel identity
/// system. Supabase anonymous sign-in instead gives the guest a *real*
/// `auth.users` row (with `is_anonymous = true`) the instant they open the
/// app — every repository, RLS policy, and provider in the app keeps
/// working completely unmodified, for guests and registered users alike.
///
/// Conversion later (`upgradeToEmail`) calls `auth.updateUser(email: ...)`
/// on that *same* session, which Supabase converts in place — the user id
/// never changes. That's true analytics + data continuity, not just a
/// mapped "old_guest_id -> new_user_id" pair.
class GuestIdentityService {
  GuestIdentityService(this._client);
  final SupabaseClient _client;

  /// Call once at app boot, before runApp(). If there's no session at all
  /// (fresh install, or a fully signed-out device), creates an anonymous
  /// one so the user can use the app immediately. If a session already
  /// exists (anonymous or registered, restored by supabase_flutter's own
  /// persistence), this is a no-op.
  ///
  /// Returns the resulting user id, or null if anonymous sign-in is
  /// unavailable (e.g. disabled in the Supabase dashboard) — callers should
  /// treat null as "fall back to requiring real sign-in," which is exactly
  /// today's pre-guest-mode behavior, so failure here is safe.
  Future<String?> bootstrap() async {
    final existing = _client.auth.currentUser;
    if (existing != null) return existing.id;

    try {
      final res = await _client.auth.signInAnonymously();
      debugPrint('[GuestIdentity] anonymous session created: ${res.user?.id}');
      return res.user?.id;
    } catch (e) {
      debugPrint(
        '[GuestIdentity] anonymous sign-in unavailable — guests will be '
        'sent to /login as before. Enable "Allow anonymous sign-ins" in '
        'Supabase → Authentication → Settings to turn on guest mode. ($e)',
      );
      return null;
    }
  }

  /// The current user's id (anonymous or registered), or null if there's
  /// truly no session.
  String? get currentId => _client.auth.currentUser?.id;

  /// True for an anonymous (not-yet-signed-up) session.
  bool get isGuest => _client.auth.currentUser?.isAnonymous ?? true;

  /// `'guest'` or `'registered'` — used as the Firebase Analytics
  /// `user_type` parameter on every event.
  String get userType => isGuest ? 'guest' : 'registered';

  /// Converts the current anonymous session to a permanent one in place by
  /// attaching an email. Supabase sends a confirmation (OTP or magic link,
  /// depending on project config) to that address; the caller still has to
  /// verify it (see [confirmUpgrade]) to complete the conversion.
  ///
  /// Throws [StateError] if called on an already-registered session —
  /// callers should check [isGuest] first.
  Future<void> beginUpgrade(String email, {String? emailRedirectTo}) async {
    if (!isGuest) {
      throw StateError('beginUpgrade() called on an already-registered user');
    }
    await _client.auth.updateUser(
      UserAttributes(email: email),
      emailRedirectTo: emailRedirectTo,
    );
  }

  /// Verifies the OTP code sent by [beginUpgrade]. On success the session's
  /// user id is unchanged but `is_anonymous` flips to false.
  Future<void> confirmUpgrade({required String email, required String token}) async {
    await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.emailChange,
    );
  }
}
