import '../auth_repository.dart';
import '../oauth_models.dart';

/// Guest → permanent, via Supabase identity linking. A thin named wrapper
/// around `AuthRepository.continueWith` — most callers should go through
/// `AuthController` instead (it also handles state/analytics/crashlytics),
/// but this exists as its own class so the "upgrade a guest" operation is
/// independently testable and has one obvious place to look for it.
class UpgradeGuestUseCase {
  const UpgradeGuestUseCase(this._repository);
  final AuthRepository _repository;

  Future<AuthOutcome> call(AuthProviderKind provider) =>
      _repository.continueWith(provider);
}
