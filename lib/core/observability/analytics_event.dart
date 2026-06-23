/// A single analytics event, fully resolved (name + merged parameters) right
/// before it's sent to Firebase and/or buffered locally. Kept as a plain
/// value type so [AnalyticsRepository] can hand the same object to Firebase,
/// the debug logger, and the local session buffer without re-deriving
/// anything three times.
class AnalyticsEvent {
  AnalyticsEvent({
    required this.name,
    required this.params,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String name;
  final Map<String, Object?> params;
  final DateTime timestamp;

  /// Firebase only accepts String/num/bool parameter values — this also
  /// drops nulls, since Firebase rejects those outright.
  Map<String, Object> toFirebaseParams() {
    final out = <String, Object>{};
    params.forEach((key, value) {
      if (value == null) return;
      if (value is String || value is num || value is bool) {
        out[key] = value;
      } else {
        out[key] = value.toString();
      }
    });
    return out;
  }

  @override
  String toString() => '$name $params';
}

/// Central registry of event name strings — avoids magic strings scattered
/// across every screen and keeps Firebase's naming (snake_case, <=40 chars)
/// consistent in one place.
class AnalyticsEvents {
  AnalyticsEvents._();

  // ─── App lifecycle ──────────────────────────────────────────────────────
  static const appOpened = 'app_opened';
  static const appForeground = 'app_foreground';
  static const appBackground = 'app_background';
  static const sessionStarted = 'session_started';
  static const sessionEnded = 'session_ended';

  // ─── Screens (automatic) ────────────────────────────────────────────────
  static const screenView = 'screen_view';

  // ─── Tutorial ───────────────────────────────────────────────────────────
  static const tutorialStarted = 'tutorial_started';
  static const tutorialCompleted = 'tutorial_completed';
  static const tutorialSkipped = 'tutorial_skipped';

  // ─── Onboarding ─────────────────────────────────────────────────────────
  static const onboardingStarted = 'onboarding_started';
  static const onboardingCompleted = 'onboarding_completed';

  // ─── Core loop ──────────────────────────────────────────────────────────
  static const vibeSelected = 'vibe_selected';
  static const categoryOpened = 'category_opened';
  static const optionSelected = 'option_selected';
  static const comingSoonTapped = 'coming_soon_tapped';

  // ─── AI decide ──────────────────────────────────────────────────────────
  static const aiDecideStarted = 'ai_decide_started';
  static const aiDecideCompleted = 'ai_decide_completed';
  static const aiReroll = 'ai_reroll';
  static const aiAccepted = 'ai_accepted';

  // ─── Response / action ──────────────────────────────────────────────────
  static const reactionLoaded = 'reaction_loaded';
  static const actionLaunched = 'action_launched';
  static const dndEntered = 'dnd_entered';
  static const shareClicked = 'share_clicked';

  // ─── Check-in / summary ─────────────────────────────────────────────────
  static const checkinStarted = 'checkin_started';
  static const checkinCompleted = 'checkin_completed';
  static const summaryViewed = 'summary_viewed';
  static const newVibeStarted = 'new_vibe_started';

  // ─── Plans ──────────────────────────────────────────────────────────────
  static const planCreated = 'plan_created';
  static const planJoined = 'plan_joined';

  // ─── Profile ────────────────────────────────────────────────────────────
  static const profileOpened = 'profile_opened';

  // ─── Notifications ──────────────────────────────────────────────────────
  static const notificationPermissionGranted = 'notification_permission_granted';
  static const notificationPermissionDenied = 'notification_permission_denied';

  // ─── Signup / conversion ────────────────────────────────────────────────
  static const signupPromptShown = 'signup_prompt_shown';
  static const signupStarted = 'signup_started';
  static const signupCompleted = 'signup_completed';
  static const guestConverted = 'guest_converted';
  static const loginCompleted = 'login_completed';
}
