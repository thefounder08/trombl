import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../identity/guest_identity_service.dart';
import '../observability/analytics_repository.dart';
import '../observability/crash_service.dart';
import '../providers.dart';
import 'auth_exceptions.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';
import 'oauth_models.dart';

/// Drives the signup sheet's UI. Holds no business logic of its own beyond
/// "call the repository, track the result, surface state" — every actual
/// decision (link vs. sign-in, profile sync, error mapping) lives in
/// [AuthRepository].
sealed class AuthControllerState {
  const AuthControllerState();
}

class AuthIdle extends AuthControllerState {
  const AuthIdle();
}

class AuthLoading extends AuthControllerState {
  const AuthLoading(this.provider);
  final AuthProviderKind provider;
}

class AuthSuccess extends AuthControllerState {
  const AuthSuccess(this.outcome);
  final AuthOutcome outcome;
}

class AuthFailed extends AuthControllerState {
  const AuthFailed(this.reason, this.provider);
  final AuthFailureReason reason;
  final AuthProviderKind provider;
}

/// Surfaced specifically so the UI can ask "sign in to that account
/// instead?" rather than [AuthFailed] silently being a dead end — this is
/// the one error case with a real recovery action.
class AuthIdentityConflict extends AuthControllerState {
  const AuthIdentityConflict(this.provider);
  final AuthProviderKind provider;
}

class AuthController extends Notifier<AuthControllerState> {
  @override
  AuthControllerState build() => const AuthIdle();

  AuthRepository get _repo => ref.read(authRepositoryProvider);
  AnalyticsRepository get _analytics => ref.read(analyticsRepositoryProvider);
  GuestIdentityService get _identity => ref.read(guestIdentityServiceProvider);

  Future<void> continueWith(AuthProviderKind provider) =>
      _run(provider, link: true);

  Future<void> signInExisting(AuthProviderKind provider) =>
      _run(provider, link: false);

  Future<void> _run(AuthProviderKind provider, {required bool link}) async {
    final wasGuest = _identity.isGuest;
    final guestCreatedAt = _identity.currentUserCreatedAt;
    _analytics.trackSignupProviderSelected(provider: provider.label);
    state = AuthLoading(provider);

    try {
      final outcome = link
          ? await _repo.continueWith(provider)
          : await _repo.signInExisting(provider);

      final durationMs = _guestLifetimeMs(guestCreatedAt);
      if (wasGuest && outcome.kind == AuthOutcomeKind.guestUpgraded) {
        _analytics.trackGuestUpgraded(provider: provider.label, guestLifetimeMs: durationMs);
        _analytics.trackSignupSuccess(provider: provider.label, method: 'link');
      } else {
        _analytics.trackLoginSuccess(provider: provider.label);
        _analytics.trackSignupSuccess(provider: provider.label, method: 'sign_in');
      }
      CrashService.setContext(
        guestId: outcome.userId,
        userType: 'registered',
        provider: provider.label,
      );
      state = AuthSuccess(outcome);
    } on AuthRepositoryException catch (e) {
      if (e.reason == AuthFailureReason.identityAlreadyLinked && link) {
        _analytics.trackSignupFailed(provider: provider.label, reason: e.reason.name);
        state = AuthIdentityConflict(provider);
        return;
      }
      _analytics.trackSignupFailed(provider: provider.label, reason: e.reason.name);
      if (!link) _analytics.trackLoginFailed(provider: provider.label, reason: e.reason.name);
      state = AuthFailed(e.reason, provider);
    }
  }

  int? _guestLifetimeMs(String? createdAtIso) {
    if (createdAtIso == null) return null;
    final createdAt = DateTime.tryParse(createdAtIso);
    if (createdAt == null) return null;
    return DateTime.now().difference(createdAt).inMilliseconds;
  }

  Future<void> signOut() async {
    final wasGuest = _identity.isGuest;
    await _repo.signOut();
    if (!wasGuest) _analytics.trackLogout();
    state = const AuthIdle();
  }

  void reset() => state = const AuthIdle();
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthControllerState>(AuthController.new);
