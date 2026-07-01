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
    case 'console_test':
      return '/notifications';
    // Future kinds:
    //   'plan_invite'        → '/p/${data['plan_token']}' or '/join-plan'
    //   'checkin_reminder'   → '/checkin'
    //   'weekly_recap'       → '/history'
    default:
      return '/home';
  }
}
