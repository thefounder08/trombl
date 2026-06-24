/// Why an auth attempt failed — drives which friendly message
/// `SignupBottomSheet` shows, never a raw exception string.
enum AuthFailureReason {
  cancelled,
  network,
  providerUnavailable,
  identityAlreadyLinked,
  emailAlreadyExists,
  oauthTimeout,
  duplicateAccount,
  supabaseError,
  unknown,
}

extension AuthFailureReasonCopy on AuthFailureReason {
  /// trom-voiced, never technical — matches the rest of the app's error
  /// copy convention (see shared/result.dart).
  String get friendlyMessage => switch (this) {
        AuthFailureReason.cancelled => "no worries, didn't sign u in.",
        AuthFailureReason.network =>
          "couldn't reach the internet. check ur connection and try again.",
        AuthFailureReason.providerUnavailable =>
          "that sign-in method isn't available rn. try the other one?",
        AuthFailureReason.identityAlreadyLinked =>
          "that account's already signed up. sign in instead and ur guest "
              "stuff from today won't carry over.",
        AuthFailureReason.emailAlreadyExists =>
          "that email's already got an account. try signing in instead.",
        AuthFailureReason.oauthTimeout => "that took too long. try again?",
        AuthFailureReason.duplicateAccount =>
          "looks like u already have an account. signing u in instead.",
        AuthFailureReason.supabaseError =>
          "something broke on our end. try again in a sec.",
        AuthFailureReason.unknown => "something went wrong. try again?",
      };
}

/// The one exception type that crosses from `AuthRepository` into
/// `AuthController` — every Supabase/OAuth/network failure gets mapped into
/// one of these so the UI layer never has to pattern-match raw SDK
/// exceptions.
class AuthRepositoryException implements Exception {
  const AuthRepositoryException(this.reason, [this.debugMessage]);
  final AuthFailureReason reason;
  final String? debugMessage;

  @override
  String toString() => 'AuthRepositoryException(${reason.name}: $debugMessage)';
}
