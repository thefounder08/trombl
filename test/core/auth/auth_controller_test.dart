import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trombl/core/auth/auth_controller.dart';
import 'package:trombl/core/auth/auth_exceptions.dart';
import 'package:trombl/core/auth/auth_providers.dart';
import 'package:trombl/core/auth/auth_repository.dart';
import 'package:trombl/core/auth/oauth_models.dart';
import 'package:trombl/core/identity/guest_identity_service.dart';
import 'package:trombl/core/observability/analytics_repository.dart';
import 'package:trombl/core/providers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockGuestIdentityService extends Mock implements GuestIdentityService {}

class MockAnalyticsRepository extends Mock implements AnalyticsRepository {}

void main() {
  late MockAuthRepository repo;
  late MockGuestIdentityService identity;
  late MockAnalyticsRepository analytics;
  late ProviderContainer container;

  setUp(() {
    repo = MockAuthRepository();
    identity = MockGuestIdentityService();
    analytics = MockAnalyticsRepository();

    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      guestIdentityServiceProvider.overrideWithValue(identity),
      analyticsRepositoryProvider.overrideWithValue(analytics),
    ]);
    addTearDown(container.dispose);
  });

  test('continueWith success moves Idle -> Loading -> Success', () async {
    when(() => identity.isGuest).thenReturn(true);
    when(() => repo.continueWith(AuthProviderKind.google)).thenAnswer(
      (_) async => const AuthOutcome(
        kind: AuthOutcomeKind.guestUpgraded,
        userId: 'uid-1',
        provider: AuthProviderKind.google,
      ),
    );

    final states = <AuthControllerState>[];
    container.listen(authControllerProvider, (_, next) => states.add(next), fireImmediately: true);

    await container.read(authControllerProvider.notifier).continueWith(AuthProviderKind.google);

    expect(states[0], isA<AuthIdle>());
    expect(states[1], isA<AuthLoading>());
    expect(states.last, isA<AuthSuccess>());
    verify(() => analytics.trackGuestUpgraded(provider: 'google', guestLifetimeMs: any(named: 'guestLifetimeMs')))
        .called(1);
  });

  test('identityAlreadyLinked surfaces AuthIdentityConflict, not AuthFailed', () async {
    when(() => identity.isGuest).thenReturn(true);
    when(() => repo.continueWith(AuthProviderKind.google)).thenThrow(
      const AuthRepositoryException(AuthFailureReason.identityAlreadyLinked),
    );

    await container.read(authControllerProvider.notifier).continueWith(AuthProviderKind.google);

    expect(container.read(authControllerProvider), isA<AuthIdentityConflict>());
  });

  test('other failures surface AuthFailed with the mapped reason', () async {
    when(() => identity.isGuest).thenReturn(true);
    when(() => repo.continueWith(AuthProviderKind.google))
        .thenThrow(const AuthRepositoryException(AuthFailureReason.network));

    await container.read(authControllerProvider.notifier).continueWith(AuthProviderKind.google);

    final state = container.read(authControllerProvider);
    expect(state, isA<AuthFailed>());
    expect((state as AuthFailed).reason, AuthFailureReason.network);
  });

  test('signInExisting goes through the repository\'s plain sign-in path', () async {
    when(() => identity.isGuest).thenReturn(false);
    when(() => repo.signInExisting(AuthProviderKind.apple)).thenAnswer(
      (_) async => const AuthOutcome(
        kind: AuthOutcomeKind.signedIntoExisting,
        userId: 'uid-2',
        provider: AuthProviderKind.apple,
      ),
    );

    await container.read(authControllerProvider.notifier).signInExisting(AuthProviderKind.apple);

    expect(container.read(authControllerProvider), isA<AuthSuccess>());
    verify(() => analytics.trackLoginSuccess(provider: 'apple')).called(1);
    verifyNever(() => analytics.trackGuestUpgraded(
          provider: any(named: 'provider'),
          guestLifetimeMs: any(named: 'guestLifetimeMs'),
        ));
  });

  test('signOut resets state to Idle and tracks logout for registered users', () async {
    when(() => identity.isGuest).thenReturn(false);
    when(() => repo.signOut()).thenAnswer((_) async {});

    await container.read(authControllerProvider.notifier).signOut();

    expect(container.read(authControllerProvider), isA<AuthIdle>());
    verify(() => analytics.trackLogout()).called(1);
  });

  test('signOut does not track logout for a guest (nothing to log out of)', () async {
    when(() => identity.isGuest).thenReturn(true);
    when(() => repo.signOut()).thenAnswer((_) async {});

    await container.read(authControllerProvider.notifier).signOut();

    verifyNever(() => analytics.trackLogout());
  });
}
