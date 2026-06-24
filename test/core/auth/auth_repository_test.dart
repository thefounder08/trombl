import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import 'package:trombl/core/auth/auth_exceptions.dart';
import 'package:trombl/core/auth/auth_repository.dart';
import 'package:trombl/core/auth/oauth_models.dart';
import 'package:trombl/core/auth/oauth_service.dart';
import 'package:trombl/core/identity/guest_identity_service.dart';
import 'package:trombl/shared/repositories/session_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockGuestIdentityService extends Mock implements GuestIdentityService {}

class MockOAuthService extends Mock implements OAuthService {}

class MockSessionRepository extends Mock implements SessionRepository {}

User _fakeUser({required String id, bool isAnonymous = false, Map<String, dynamic>? metadata}) {
  return User(
    id: id,
    appMetadata: const {},
    userMetadata: metadata,
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
    isAnonymous: isAnonymous,
  );
}

const _googleCredential = NativeAuthCredential(
  provider: AuthProviderKind.google,
  idToken: 'fake-id-token',
);

void main() {
  setUpAll(() {
    registerFallbackValue(OAuthProvider.google);
  });

  late MockSupabaseClient client;
  late MockGoTrueClient auth;
  late MockGuestIdentityService identity;
  late MockOAuthService oauth;
  late MockSessionRepository sessionRepo;
  late AuthRepository repo;

  setUp(() {
    client = MockSupabaseClient();
    auth = MockGoTrueClient();
    identity = MockGuestIdentityService();
    oauth = MockOAuthService();
    sessionRepo = MockSessionRepository();
    when(() => client.auth).thenReturn(auth);
    repo = AuthRepository(client, identity, oauth, sessionRepo);

    // Profile sync defaults — most tests don't care about this path.
    when(() => sessionRepo.getProfile()).thenAnswer((_) async => null);
    when(() => sessionRepo.updateProfile(displayName: any(named: 'displayName')))
        .thenAnswer((_) async {});
    when(() => sessionRepo.updateOAuthProfileFields(
          avatarUrl: any(named: 'avatarUrl'),
          email: any(named: 'email'),
          authProvider: any(named: 'authProvider'),
        )).thenAnswer((_) async {});
  });

  group('continueWith — guest upgrade', () {
    test('links identity and preserves the anonymous uid', () async {
      when(() => identity.isGuest).thenReturn(true);
      when(() => oauth.signInWithGoogle()).thenAnswer((_) async => _googleCredential);
      final upgradedUser = _fakeUser(id: 'guest-uid-123');
      when(() => auth.linkIdentityWithIdToken(
            provider: OAuthProvider.google,
            idToken: 'fake-id-token',
            nonce: null,
          )).thenAnswer((_) async => AuthResponse(user: upgradedUser));

      final outcome = await repo.continueWith(AuthProviderKind.google);

      expect(outcome.kind, AuthOutcomeKind.guestUpgraded);
      expect(outcome.userId, 'guest-uid-123');
      verify(() => auth.linkIdentityWithIdToken(
            provider: OAuthProvider.google,
            idToken: 'fake-id-token',
            nonce: null,
          )).called(1);
      verifyNever(() => auth.signInWithIdToken(
            provider: any(named: 'provider'),
            idToken: any(named: 'idToken'),
          ));
    });

    test('maps "identity already linked" to AuthFailureReason.identityAlreadyLinked', () async {
      when(() => identity.isGuest).thenReturn(true);
      when(() => oauth.signInWithGoogle()).thenAnswer((_) async => _googleCredential);
      when(() => auth.linkIdentityWithIdToken(
            provider: OAuthProvider.google,
            idToken: 'fake-id-token',
            nonce: null,
          )).thenThrow(const AuthException(
        'Identity is already linked to another user',
        code: 'identity_already_exists',
      ));

      await expectLater(
        repo.continueWith(AuthProviderKind.google),
        throwsA(isA<AuthRepositoryException>()
            .having((e) => e.reason, 'reason', AuthFailureReason.identityAlreadyLinked)),
      );
    });

    test('does not call Supabase at all if the OAuth picker is cancelled', () async {
      when(() => identity.isGuest).thenReturn(true);
      when(() => oauth.signInWithGoogle())
          .thenThrow(const OAuthCancelledException(AuthProviderKind.google));

      await expectLater(
        repo.continueWith(AuthProviderKind.google),
        throwsA(isA<AuthRepositoryException>()
            .having((e) => e.reason, 'reason', AuthFailureReason.cancelled)),
      );
      verifyNever(() => auth.linkIdentityWithIdToken(
            provider: any(named: 'provider'),
            idToken: any(named: 'idToken'),
          ));
    });
  });

  group('continueWith — already registered', () {
    test('signs in normally instead of linking', () async {
      when(() => identity.isGuest).thenReturn(false);
      when(() => oauth.signInWithGoogle()).thenAnswer((_) async => _googleCredential);
      final user = _fakeUser(id: 'registered-uid');
      when(() => auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: 'fake-id-token',
            nonce: null,
          )).thenAnswer((_) async => AuthResponse(user: user));

      final outcome = await repo.continueWith(AuthProviderKind.google);

      expect(outcome.kind, AuthOutcomeKind.signedIntoExisting);
      verifyNever(() => auth.linkIdentityWithIdToken(
            provider: any(named: 'provider'),
            idToken: any(named: 'idToken'),
          ));
    });
  });

  group('signInExisting', () {
    test('always calls the plain sign-in path regardless of guest status', () async {
      when(() => identity.isGuest).thenReturn(true); // even if guest...
      when(() => oauth.signInWithGoogle()).thenAnswer((_) async => _googleCredential);
      final user = _fakeUser(id: 'existing-uid');
      when(() => auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: 'fake-id-token',
            nonce: null,
          )).thenAnswer((_) async => AuthResponse(user: user));

      final outcome = await repo.signInExisting(AuthProviderKind.google);

      expect(outcome.kind, AuthOutcomeKind.signedIntoExisting);
      expect(outcome.userId, 'existing-uid');
    });
  });

  group('signOut', () {
    test('signs out then re-bootstraps a guest session', () async {
      when(() => oauth.signOutGoogle()).thenAnswer((_) async {});
      when(() => auth.signOut()).thenAnswer((_) async {});
      when(() => identity.bootstrap()).thenAnswer((_) async => 'new-guest-id');

      await repo.signOut();

      verifyInOrder([
        () => auth.signOut(),
        () => identity.bootstrap(),
      ]);
    });
  });
}
