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
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/setup', builder: (_, __) => const SetupScreen()),
      GoRoute(path: '/vibe', builder: (_, __) => const VibeScreen()),
      GoRoute(path: '/menu', builder: (_, __) => const MenuScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(
        path: '/response',
        builder: (_, state) =>
            ResponseScreen(args: state.extra! as ResponseArgs),
      ),
      GoRoute(path: '/checkin', builder: (_, __) => const CheckinScreen()),
      GoRoute(
        path: '/summary',
        builder: (_, state) =>
            DaySummaryScreen(args: state.extra! as DaySummaryScreenArgs),
      ),
      GoRoute(
        path: '/plan/:id',
        builder: (_, state) =>
            PlanDetailScreen(planId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/join-plan', builder: (_, __) => const JoinPlanScreen()),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
    ],
  );
});

/// Bridges Riverpod auth changes to GoRouter's refresh.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}
