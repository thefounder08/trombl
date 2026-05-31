import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/repositories/plan_repository.dart';
import '../../../shared/result.dart';
import '../../vibe/providers/session_providers.dart';

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository(ref.watch(supabaseProvider));
});

// ── My plans list ────────────────────────────────────────────────────────────

final myPlansProvider =
    FutureProvider.autoDispose<List<Plan>>((ref) async {
  return ref.watch(planRepositoryProvider).myPlans();
});

// ── Plan detail (by id) ──────────────────────────────────────────────────────

final planDetailProvider =
    FutureProvider.autoDispose.family<Plan?, String>((ref, planId) async {
  final plans = await ref.watch(myPlansProvider.future);
  final match = plans.where((p) => p.id == planId).toList();
  if (match.isNotEmpty) return match.first;
  // Not in cache — fetch directly (e.g. after joining)
  final rows = await ref
      .read(supabaseProvider)
      .from('plans')
      .select()
      .eq('id', planId);
  if ((rows as List).isEmpty) return null;
  return Plan.fromJson(rows.first);
});

final planMembersProvider =
    FutureProvider.autoDispose.family<List<PlanMember>, String>(
        (ref, planId) async {
  return ref.watch(planRepositoryProvider).membersFor(planId);
});

final myMembershipProvider =
    FutureProvider.autoDispose.family<PlanMember?, String>(
        (ref, planId) async {
  return ref.watch(planRepositoryProvider).myMembership(planId);
});

final memberProfilesProvider =
    FutureProvider.autoDispose.family<Map<String, Profile>, String>(
        (ref, planId) async {
  final members = await ref.watch(planMembersProvider(planId).future);
  final userIds = members.map((m) => m.userId).toList();
  return ref.read(sessionRepositoryProvider).profilesForUsers(userIds);
});

final currentProfileProvider =
    FutureProvider.autoDispose<Profile?>((ref) async {
  return ref.watch(sessionRepositoryProvider).getProfile();
});

// Owner profile for a given plan — resolves ownerId → Profile.
// Used on the detail screen to show "X's plan" vs "your plan".
final planOwnerProfileProvider =
    FutureProvider.autoDispose.family<Profile?, String>((ref, planId) async {
  final plan = await ref.watch(planDetailProvider(planId).future);
  if (plan == null) return null;
  final map = await ref
      .read(sessionRepositoryProvider)
      .profilesForUsers([plan.ownerId]);
  return map[plan.ownerId];
});

// Count of 'in' members for a plan — shown on the "your plans" menu row.
final planInCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, planId) async {
  final members = await ref.watch(planMembersProvider(planId).future);
  return members.where((m) => m.status == 'in').length;
});

// ── RSVP notifier ────────────────────────────────────────────────────────────

class RsvpNotifier extends AutoDisposeFamilyNotifier<AsyncValue<String?>, String> {
  @override
  AsyncValue<String?> build(String arg) => const AsyncValue.data(null);

  Future<void> update(String status) async {
    state = const AsyncValue.loading();
    final Result<PlanMember> result =
        await ref.read(planRepositoryProvider).joinOrUpdate(arg, status);
    state = switch (result) {
      Success(:final data) => AsyncValue.data(data.status),
      Failure(:final error) => AsyncValue.error(error, StackTrace.empty),
    };
    ref.invalidate(myMembershipProvider(arg));
    ref.invalidate(planMembersProvider(arg));
  }
}

final rsvpProvider =
    NotifierProvider.autoDispose.family<RsvpNotifier, AsyncValue<String?>, String>(
        RsvpNotifier.new);

// ── Cancel plan (owner only) ─────────────────────────────────────────────────

class CancelPlanNotifier extends AutoDisposeNotifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<String?> cancel(String planId) async {
    state = const AsyncValue.loading();
    final result = await ref.read(planRepositoryProvider).deletePlan(planId);
    return switch (result) {
      Success() => _done(),
      Failure(:final error) => _fail(error),
    };
  }

  String? _done() {
    state = const AsyncValue.data(null);
    ref.invalidate(myPlansProvider);
    return null;
  }

  String? _fail(String error) {
    state = AsyncValue.error(error, StackTrace.empty);
    return error;
  }
}

final cancelPlanProvider =
    NotifierProvider.autoDispose<CancelPlanNotifier, AsyncValue<void>>(
        CancelPlanNotifier.new);
