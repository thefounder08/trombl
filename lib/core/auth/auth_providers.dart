import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/vibe/providers/session_providers.dart';
import '../providers.dart';
import 'auth_repository.dart';
import 'oauth_service.dart';

/// Lives outside `core/providers.dart` deliberately: it depends on
/// `sessionRepositoryProvider`, which (matching this codebase's existing
/// layering — see `decide_providers.dart`) is defined alongside the
/// `vibe` feature rather than in core. Keeping cross-cutting-but-not-root
/// composition like this in its own file avoids a core → features import
/// inside `providers.dart` itself.
final oauthServiceProvider = Provider<OAuthService>((ref) => OAuthService());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(supabaseProvider),
    ref.watch(guestIdentityServiceProvider),
    ref.watch(oauthServiceProvider),
    ref.watch(sessionRepositoryProvider),
  );
});
