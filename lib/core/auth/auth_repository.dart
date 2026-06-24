import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../identity/guest_identity_service.dart';
import '../../shared/repositories/session_repository.dart';
import 'auth_exceptions.dart';
import 'oauth_models.dart';
import 'oauth_service.dart';

/// What changed as a result of a sign-in attempt — [AuthController] uses
/// this (rather than just "it succeeded") to decide which analytics event
/// fires and what the UI should say.
enum AuthOutcomeKind { guestUpgraded, signedIntoExisting }

class AuthOutcome {
  const AuthOutcome({required this.kind, required this.userId, required this.provider});
  final AuthOutcomeKind kind;
  final String userId;
  final AuthProviderKind provider;
}

OAuthProvider _supabaseProvider(AuthProviderKind kind) => switch (kind) {
      AuthProviderKind.google => OAuthProvider.google,
      AuthProviderKind.apple => OAuthProvider.apple,
    };

/// Combines [OAuthService] (native token acquisition) with Supabase Auth's
/// identity-linking API to implement the guest→permanent upgrade without
/// ever creating a second user for the same person.
///
/// The core trick, twice: `linkIdentityWithIdToken` attaches a new
/// provider identity to *whatever session is currently active* — including
/// an anonymous one — without changing its user id. `signInWithIdToken` is
/// the opposite: a normal sign-in/sign-up that ignores any current session.
/// Which one to call is the entire guest-upgrade-vs-existing-account
/// decision; everything else in this app (repositories, RLS, analytics) is
/// unaffected either way because the user id this resolves to is the only
/// thing that matters to them.
class AuthRepository {
  AuthRepository(this._client, this._guestIdentity, this._oauthService, this._sessionRepo);

  final SupabaseClient _client;
  final GuestIdentityService _guestIdentity;
  final OAuthService _oauthService;
  final SessionRepository _sessionRepo;

  /// The primary entrypoint from the signup sheet. If the current session
  /// is a guest, this *links* — the guest's `sessions`/`picks`/`ai_picks`/
  /// `memory_nodes` all stay attached to the same id. If it isn't (already
  /// registered, or somehow no session at all), this signs in/up normally.
  ///
  /// Throws [AuthRepositoryException] with
  /// [AuthFailureReason.identityAlreadyLinked] if the chosen Google/Apple
  /// account already has a *different* trombl account — the caller must
  /// explicitly decide whether to fall back to [signInExisting] (which
  /// abandons the current guest session) rather than this method ever
  /// doing that silently.
  Future<AuthOutcome> continueWith(AuthProviderKind providerKind) async {
    final wasGuest = _guestIdentity.isGuest;
    final credential = await _acquireCredential(providerKind);

    if (!wasGuest) {
      return _signInExisting(credential);
    }
    return _link(credential, outcomeKind: AuthOutcomeKind.guestUpgraded);
  }

  /// Attaches an additional provider identity to *whatever* the current
  /// session is — guest or already-registered. Distinct from
  /// [continueWith]: that method's whole job is deciding link-vs-sign-in
  /// based on guest status; this one is for the "Account linking" case
  /// proper — e.g. a already-registered Google user adding Apple as a
  /// second way to sign in to the *same* account. Used by
  /// `LinkAccountUseCase`.
  Future<AuthOutcome> linkAdditionalIdentity(AuthProviderKind providerKind) async {
    final credential = await _acquireCredential(providerKind);
    return _link(credential, outcomeKind: AuthOutcomeKind.guestUpgraded);
  }

  Future<AuthOutcome> _link(
    NativeAuthCredential credential, {
    required AuthOutcomeKind outcomeKind,
  }) async {
    try {
      final response = await _client.auth.linkIdentityWithIdToken(
        provider: _supabaseProvider(credential.provider),
        idToken: credential.idToken,
        nonce: credential.rawNonce,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthRepositoryException(AuthFailureReason.supabaseError);
      }
      await _syncProfile(user, credential);
      return AuthOutcome(kind: outcomeKind, userId: user.id, provider: credential.provider);
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      if (e is AuthRepositoryException) rethrow;
      throw AuthRepositoryException(AuthFailureReason.unknown, e.toString());
    }
  }

  /// Explicit "no, sign me into my other account" path — used either when
  /// the user was never a guest to begin with, or as the user-confirmed
  /// fallback after [continueWith] throws `identityAlreadyLinked`. This
  /// **abandons** the current anonymous session; anything written under it
  /// (today's picks, sessions) is not recoverable from here.
  Future<AuthOutcome> signInExisting(AuthProviderKind providerKind) async {
    final credential = await _acquireCredential(providerKind);
    return _signInExisting(credential);
  }

  Future<AuthOutcome> _signInExisting(NativeAuthCredential credential) async {
    try {
      final response = await _client.auth.signInWithIdToken(
        provider: _supabaseProvider(credential.provider),
        idToken: credential.idToken,
        nonce: credential.rawNonce,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthRepositoryException(AuthFailureReason.supabaseError);
      }
      await _syncProfile(user, credential);
      return AuthOutcome(
        kind: AuthOutcomeKind.signedIntoExisting,
        userId: user.id,
        provider: credential.provider,
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      if (e is AuthRepositoryException) rethrow;
      throw AuthRepositoryException(AuthFailureReason.unknown, e.toString());
    }
  }

  Future<NativeAuthCredential> _acquireCredential(AuthProviderKind kind) async {
    try {
      return switch (kind) {
        AuthProviderKind.google => await _oauthService.signInWithGoogle(),
        AuthProviderKind.apple => await _oauthService.signInWithApple(),
      };
    } on OAuthCancelledException {
      throw const AuthRepositoryException(AuthFailureReason.cancelled);
    } on OAuthUnavailableException catch (e) {
      throw AuthRepositoryException(AuthFailureReason.providerUnavailable, e.message);
    }
  }

  /// Maps Supabase's error codes/messages onto our typed reasons. Codes per
  /// https://supabase.com/docs/guides/auth/debugging/error-codes — matched
  /// defensively on both `code` and `message` since older self-hosted
  /// Supabase versions don't always populate `code`.
  AuthRepositoryException _mapAuthException(AuthException e) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();
    if (code == 'identity_already_exists' || msg.contains('identity is already linked')) {
      return AuthRepositoryException(AuthFailureReason.identityAlreadyLinked, e.message);
    }
    if (code == 'email_exists' || msg.contains('already registered') || msg.contains('already exists')) {
      return AuthRepositoryException(AuthFailureReason.emailAlreadyExists, e.message);
    }
    if (code == 'over_request_rate_limit' || code == 'request_timeout' || msg.contains('timeout')) {
      return AuthRepositoryException(AuthFailureReason.oauthTimeout, e.message);
    }
    if (e.statusCode == '0' || msg.contains('network') || msg.contains('connection')) {
      return AuthRepositoryException(AuthFailureReason.network, e.message);
    }
    return AuthRepositoryException(AuthFailureReason.supabaseError, e.message);
  }

  /// Writes provider-sourced profile data, but **never** overwrites a
  /// `display_name` the user already set themselves — `avatar_url`/
  /// `email`/`auth_provider` are new fields with no prior user edits to
  /// protect, so those are always kept in sync with the provider.
  Future<void> _syncProfile(User user, NativeAuthCredential credential) async {
    try {
      final existing = await _sessionRepo.getProfile();
      final metadata = user.userMetadata ?? const {};
      final providerName =
          (metadata['full_name'] as String?) ?? (metadata['name'] as String?) ?? credential.fullName;
      final avatarUrl = (metadata['avatar_url'] as String?) ?? (metadata['picture'] as String?);
      final email = user.email ?? credential.email;

      if ((existing?.displayName == null || existing!.displayName!.trim().isEmpty) &&
          providerName != null &&
          providerName.trim().isNotEmpty) {
        await _sessionRepo.updateProfile(displayName: providerName.trim());
      }

      await _sessionRepo.updateOAuthProfileFields(
        avatarUrl: avatarUrl,
        email: email,
        authProvider: credential.provider.label,
      );
    } catch (e) {
      // Profile sync is best-effort — never block a successful sign-in on it.
      debugPrint('[AuthRepository] profile sync failed (non-fatal): $e');
    }
  }

  /// Signs out, then immediately re-bootstraps a fresh anonymous session so
  /// the app is never in a true logged-out dead end — consistent with the
  /// rest of this app's "no login wall" architecture. Never touches the
  /// permanent account being signed out of; this is a session change, not
  /// a deletion.
  Future<void> signOut() async {
    await _oauthService.signOutGoogle();
    await _client.auth.signOut();
    await _guestIdentity.bootstrap();
  }
}
