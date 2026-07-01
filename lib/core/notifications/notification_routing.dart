/// Maps a notification `kind` (+ its `data` payload) to a route to push
/// when the notification is tapped — from a push (foreground, backgrounded,
/// or killed-app) or from the in-app notification center.
///
/// Backend sends only `kind` today, with no destination-specific fields in
/// `data` yet (see send-nudge/dispatch-nudges). Until per-kind routes are
/// defined, everything resolves to the same default landing spot.
String resolveNotificationRoute(String kind, Map<String, dynamic> data) {
  switch (kind) {
    case 'daily_nudge':
      return '/decide';
    case 'vibe_check':
      return '/vibe';
    case 'checkin_reminder':
      return '/checkin';
    case 'weekly_recap':
      return '/history';
    case 'plan_invite':
      final token = data['plan_token'] as String?;
      return token != null ? '/p/$token' : '/home';
    case 'trom_message':
      final seed = Uri.encodeQueryComponent(
          (data['seed_text'] as String?) ?? "hey, what's on ur mind?");
      return '/chat?seed=$seed';
    case 'day_summary':
      final sessionId = data['session_id'] as String?;
      return sessionId != null ? '/day-summary/$sessionId' : '/home';
    case 'console_test':
      return '/notifications';
    default:
      return '/home';
  }
}
