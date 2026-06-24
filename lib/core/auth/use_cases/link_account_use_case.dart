import '../auth_repository.dart';
import '../oauth_models.dart';

/// Attaches a second sign-in method to an *already-registered* account
/// (e.g. a Google user adding Apple) — not the guest-upgrade flow, which is
/// `UpgradeGuestUseCase`. Both ultimately call Supabase's identity-linking
/// API, but this one is guest-status-agnostic by design: see
/// `AuthRepository.linkAdditionalIdentity`.
class LinkAccountUseCase {
  const LinkAccountUseCase(this._repository);
  final AuthRepository _repository;

  Future<AuthOutcome> call(AuthProviderKind provider) =>
      _repository.linkAdditionalIdentity(provider);
}
