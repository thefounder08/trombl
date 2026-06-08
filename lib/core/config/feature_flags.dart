// ROADMAP: replace static consts with remote config so flags can be
// flipped without a redeploy. Options:
// A. Supabase table: app_config(key text, value text) — fetch on app start,
//    cache locally, fall back to these defaults if fetch fails.
// B. Firebase Remote Config — if Firebase is added for notifications anyway.
// For now: static consts are the source of truth. Change here + redeploy.

/// Single source of truth for all feature flags.
/// To toggle a flag: change the value here and redeploy.
/// Future: replace with remote config (Supabase table or Firebase RC)
/// so flags can be flipped without a redeploy at all.
class FeatureFlags {
  // AUTH

  /// When false: no email confirmation, users sign in immediately via
  ///   onAuthStateChange after signInWithOtp. No OTP code entry needed.
  /// When true: magic link sent, user must click to confirm.
  ///   signInWithOtp called with emailRedirectTo; /auth/callback resolves session.
  /// Current state: false (email confirmation disabled in Supabase dashboard).
  /// To re-enable: set to true AND enable "Confirm email" in Supabase dashboard.
  static const bool emailConfirmationEnabled = false;

  // FUTURE FLAGS (add here as needed, never scattered in feature code)

  // static const bool pushNotificationsEnabled = false;
  // When true: request push permission post-login, save token to push_tokens.
  // Requires: Firebase project + google-services.json (blocked on Google account).

  // static const bool placesApiEnabled = false;
  // When true: picker uses Google Places API for real venue names.
  // When false: picker gives method-based suggestions (current behavior).

  // static const bool weeklyCardEnabled = false;
  // When true: generate and show weekly recap card on profile screen.
  // When false: profile shows computed stats only.

  // static const bool planInviteEnabled = true;
  // The invite/plan flow. Currently true — built and working.
}
