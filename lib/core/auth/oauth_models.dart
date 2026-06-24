/// Provider identifiers used throughout the auth stack — kept separate from
/// `supabase_flutter`'s `OAuthProvider` so `OAuthService` (the pure
/// platform-token layer) doesn't need to import Supabase at all.
enum AuthProviderKind { google, apple }

extension AuthProviderKindLabel on AuthProviderKind {
  String get label => switch (this) {
        AuthProviderKind.google => 'google',
        AuthProviderKind.apple => 'apple',
      };
}

/// A native ID token plus the raw nonce that produced it (Apple requires the
/// *raw* nonce be sent to Supabase, while the *hashed* nonce is what's sent
/// to Apple's own authorization request — see `OAuthService._generateNonce`).
class NativeAuthCredential {
  const NativeAuthCredential({
    required this.provider,
    required this.idToken,
    this.rawNonce,
    this.email,
    this.fullName,
  });

  final AuthProviderKind provider;
  final String idToken;
  final String? rawNonce;

  /// Only populated when the provider hands it back directly (Apple, and
  /// only on first authorization) — used purely to pre-fill `profiles` if
  /// Supabase's own `userMetadata` doesn't carry it.
  final String? email;
  final String? fullName;
}

/// Thrown by [OAuthService] for anything that happens *before* a token ever
/// reaches Supabase — cancellation, missing platform config, etc. Kept
/// distinct from `AuthRepositoryException` (which wraps Supabase-side
/// failures) so `AuthController` can show different copy for "you closed
/// the picker" vs. "the server rejected this."
class OAuthCancelledException implements Exception {
  const OAuthCancelledException(this.provider);
  final AuthProviderKind provider;
}

class OAuthUnavailableException implements Exception {
  const OAuthUnavailableException(this.provider, this.message);
  final AuthProviderKind provider;
  final String message;
  @override
  String toString() => 'OAuthUnavailableException(${provider.label}): $message';
}
