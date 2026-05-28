import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../../features/onboarding/presentation/login_screen.dart';
import '../../features/onboarding/presentation/setup_screen.dart';
import '../../features/vibe/presentation/vibe_screen.dart';
import '../../features/menu/presentation/menu_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/response/presentation/response_screen.dart';
import '../../features/checkin/presentation/checkin_screen.dart';
import '../../features/checkin/presentation/day_summary_screen.dart';
import '../../features/plans/presentation/plan_detail_screen.dart';
import '../../features/plans/presentation/join_plan_screen.dart';
import '../../features/history/presentation/history_screen.dart';

/// Shared transition: fade + 16px upward float.
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

/// Auth-aware routing. Signed-out users land on /login; signed-in users
/// start at /vibe (the first real moment — pick a vibe).
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = ref.read(currentUserProvider) != null;
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/vibe';
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
        pageBuilder: (_, s) =>
            _page(s.pageKey, ResponseScreen(args: s.extra! as ResponseArgs)),
      ),
      GoRoute(
        path: '/checkin',
        pageBuilder: (_, s) => _page(s.pageKey, const CheckinScreen()),
      ),
      GoRoute(
        path: '/summary',
        pageBuilder: (_, s) => _page(
            s.pageKey, DaySummaryScreen(args: s.extra! as DaySummaryScreenArgs)),
      ),
      GoRoute(
        path: '/plan/:id',
        pageBuilder: (_, s) => _page(
            s.pageKey, PlanDetailScreen(planId: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/join-plan',
        pageBuilder: (_, s) => _page(s.pageKey, const JoinPlanScreen()),
      ),
      GoRoute(
        path: '/history',
        pageBuilder: (_, s) => _page(s.pageKey, const HistoryScreen()),
      ),
    ],
  );
});

/// Bridges Riverpod auth changes to GoRouter's refresh.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}
