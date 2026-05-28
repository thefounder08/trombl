import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/repositories/plan_repository.dart';
import '../../../shared/result.dart';

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
  final uid = ref.read(supabaseProvider).auth.currentUser!.id;
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
