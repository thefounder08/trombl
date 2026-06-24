import '../auth_repository.dart';
import '../oauth_models.dart';

/// Sign in to an *existing* permanent account — never links, never
/// preserves whatever guest session was active. Used both for users who
/// were never a guest and as the explicit fallback after an
/// `identityAlreadyLinked` conflict during upgrade.
class LoginUseCase {
  const LoginUseCase(this._repository);
  final AuthRepository _repository;

  Future<AuthOutcome> call(AuthProviderKind provider) =>
      _repository.signInExisting(provider);
}
