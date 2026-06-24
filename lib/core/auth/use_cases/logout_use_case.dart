import '../auth_repository.dart';

/// Signs out of a permanent account and re-bootstraps a fresh guest
/// session — see `AuthRepository.signOut` for why "log out" never leaves
/// this app at a true logged-out dead end.
class LogoutUseCase {
  const LogoutUseCase(this._repository);
  final AuthRepository _repository;

  Future<void> call() => _repository.signOut();
}
