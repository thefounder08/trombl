import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../../features/onboarding/presentation/login_screen.dart';
import '../../features/onboarding/presentation/setup_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/tutorial_screen.dart';
import '../../features/vibe/presentation/vibe_screen.dart';
import '../../features/menu/presentation/menu_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/response/presentation/response_screen.dart';
import '../../features/response/presentation/dnd_screen.dart';
import '../../features/checkin/presentation/checkin_screen.dart';
import '../../features/checkin/presentation/day_summary_screen.dart';
import '../../features/summary/presentation/summary_screen.dart';
import '../../features/plan/presentation/plan_landing_screen.dart';
import '../../features/plan/presentation/create_plan_screen.dart';
import '../../features/plans/presentation/plan_detail_screen.dart';
import '../../features/plans/presentation/join_plan_screen.dart';
import '../../features/decide/presentation/decide_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/chat/presentation/chat_args.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/journal/presentation/journal_screen.dart';
import '../../features/notifications/presentation/notification_center_screen.dart';

/// Shared fade+float page transition.
Page<T> _page<T>(LocalKey key, Widget child) => CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

/// Auth-aware routing. Public paths bypass the login guard so plan invite
/// links work without requiring sign-in first.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = ref.read(currentUserProvider) != null;
      final loc = state.matchedLocation;
      final onLogin = loc == '/login';
      // /p/:token is public — visible to unauthenticated users.
      final isPublic = loc.startsWith('/p/');
      if (!loggedIn && !onLogin && !isPublic) return '/login';
      if (loggedIn && onLogin) {
        // Magic-link click lands here signed in — return to plan if one is pending.
        final pendingToken = ref.read(pendingPlanTokenProvider);
        if (pendingToken != null) {
          ref.read(pendingPlanTokenProvider.notifier).state = null;
          return '/p/$pendingToken';
        }
        return '/vibe';
      }
      return null;
    },
    refreshListenable: _AuthRefresh(ref),
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (_, s) => _page(s.pageKey, const LoginScreen()),
      ),
      GoRoute(
        path: '/setup',
        pageBuilder: (_, s) => _page(s.pageKey, const SetupScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, s) => _page(s.pageKey, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/tutorial',
        pageBuilder: (_, s) => _page(s.pageKey, const TutorialScreen()),
      ),
      GoRoute(
        path: '/vibe',
        pageBuilder: (_, s) => _page(s.pageKey, const VibeScreen()),
      ),
      GoRoute(
        path: '/menu',
        pageBuilder: (_, s) => _page(s.pageKey, const MenuScreen()),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (_, s) => _page(s.pageKey, const ProfileScreen()),
      ),
      GoRoute(
        path: '/response',
        // `extra` is in-memory only — lost on hot restart, web URL refresh,
        // or Android process death. Bounce home instead of crashing on the
        // null-check when the router tries to rebuild this page from a
        // restored route with no surviving args.
        redirect: (_, s) => s.extra is ResponseArgs ? null : '/home',
        pageBuilder: (_, s) =>
            _page(s.pageKey, ResponseScreen(args: s.extra as ResponseArgs)),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (_, s) => _page(s.pageKey, const HomeScreen()),
      ),
      GoRoute(
        path: '/decide',
        pageBuilder: (_, s) => _page(s.pageKey, const DecideScreen()),
      ),
      GoRoute(
        path: '/dnd',
        pageBuilder: (_, s) => _page(s.pageKey, const DndScreen()),
      ),
      GoRoute(
        path: '/checkin',
        pageBuilder: (_, s) => _page(s.pageKey, const CheckinScreen()),
      ),
      // /summary — hardcoded reactive verdict (spec Commit 3)
      GoRoute(
        path: '/summary',
        redirect: (_, s) => s.extra is SummaryArgs ? null : '/home',
        pageBuilder: (_, s) =>
            _page(s.pageKey, SummaryScreen(args: s.extra as SummaryArgs)),
      ),
      // /day-summary — LLM-generated end-of-day narrative (legacy, still reachable)
      GoRoute(
        path: '/day-summary',
        redirect: (_, s) => s.extra is DaySummaryScreenArgs ? null : '/home',
        pageBuilder: (_, s) => _page(
            s.pageKey, DaySummaryScreen(args: s.extra as DaySummaryScreenArgs)),
      ),
      GoRoute(
        path: '/plan/:id',
        pageBuilder: (_, s) => _page(
            s.pageKey, PlanDetailScreen(planId: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/create-plan',
        redirect: (_, s) => s.extra is CreatePlanArgs ? null : '/home',
        pageBuilder: (_, s) =>
            _page(s.pageKey, CreatePlanScreen(args: s.extra as CreatePlanArgs)),
      ),
      GoRoute(
        path: '/join-plan',
        pageBuilder: (_, s) => _page(s.pageKey, const JoinPlanScreen()),
      ),
      // Public — no auth required. Deep-link: trombl.app/p/{token}
      // Routes to PlanLandingScreen (shows plan details + i'm in / can't tonight).
      GoRoute(
        path: '/p/:token',
        pageBuilder: (_, s) => _page(
          s.pageKey,
          PlanLandingScreen(token: s.pathParameters['token']!),
        ),
      ),
      GoRoute(
        path: '/history',
        pageBuilder: (_, s) => _page(s.pageKey, const HistoryScreen()),
      ),
      GoRoute(
        path: '/chat',
        redirect: (_, s) => s.extra is ChatArgs ? null : '/home',
        pageBuilder: (_, s) =>
            _page(s.pageKey, ChatScreen(args: s.extra as ChatArgs)),
      ),
      GoRoute(
        path: '/journal',
        pageBuilder: (_, s) => _page(s.pageKey, const JournalScreen()),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (_, s) =>
            _page(s.pageKey, const NotificationCenterScreen()),
      ),
    ],
  );
});

/// Bridges Riverpod auth changes to GoRouter's refresh mechanism.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}
