/// Maps a notification `kind` (+ its `data` payload) to a route to push
/// when the notification is tapped — from a push (foreground, backgrounded,
/// or killed-app) or from the in-app notification center.
///
/// Backend sends only `kind` today, with no destination-specific fields in
/// `data` yet (see send-nudge/dispatch-nudges). Until per-kind routes are
/// defined, everything resolves to the same default landing spot.
String resolveNotificationRoute(String kind, Map<String, dynamic> data) {
  switch (kind) {
    // TODO: route specific kinds to their relevant screen once the backend
    // attaches the data needed to do so (e.g. a plan_id for plan-related
    // nudges, a session id for daily_nudge, etc).
    default:
      return '/home';
  }
}
