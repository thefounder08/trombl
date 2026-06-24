import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trombl/core/auth/auth_providers.dart';
import 'package:trombl/core/auth/auth_repository.dart';
import 'package:trombl/core/auth/oauth_models.dart';
import 'package:trombl/core/identity/guest_identity_service.dart';
import 'package:trombl/core/observability/analytics_repository.dart';
import 'package:trombl/core/providers.dart';
import 'package:trombl/features/auth/presentation/signup_bottom_sheet.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockGuestIdentityService extends Mock implements GuestIdentityService {}

class MockAnalyticsRepository extends Mock implements AnalyticsRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(AuthProviderKind.google);
  });

  late MockAuthRepository repo;
  late MockGuestIdentityService identity;
  late MockAnalyticsRepository analytics;

  setUp(() {
    repo = MockAuthRepository();
    identity = MockGuestIdentityService();
    analytics = MockAnalyticsRepository();
    when(() => identity.isGuest).thenReturn(true);
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          guestIdentityServiceProvider.overrideWithValue(identity),
          analyticsRepositoryProvider.overrideWithValue(analytics),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showSignupBottomSheet(context, surface: 'test'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows both provider buttons and tracks the prompt view', (tester) async {
    await pumpSheet(tester);

    expect(find.text('continue with google'), findsOneWidget);
    expect(find.text('continue with apple'), findsOneWidget);
    expect(find.text('maybe later'), findsOneWidget);
    verify(() => analytics.trackGuestSignupPromptViewed(surface: 'test')).called(1);
  });

  testWidgets('tapping Google calls AuthController.continueWith(google)', (tester) async {
    when(() => repo.continueWith(AuthProviderKind.google)).thenAnswer(
      (_) async => const AuthOutcome(
        kind: AuthOutcomeKind.guestUpgraded,
        userId: 'uid',
        provider: AuthProviderKind.google,
      ),
    );

    await pumpSheet(tester);
    await tester.tap(find.text('continue with google'));
    await tester.pumpAndSettle();

    verify(() => repo.continueWith(AuthProviderKind.google)).called(1);
  });

  testWidgets('maybe later dismisses without calling the repository', (tester) async {
    await pumpSheet(tester);
    await tester.tap(find.text('maybe later'));
    await tester.pumpAndSettle();

    expect(find.text('continue with google'), findsNothing);
    verifyNever(() => repo.continueWith(any()));
  });
}
