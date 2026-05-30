import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../models/models.dart';
import '../result.dart';

class PlanRepository {
  PlanRepository(this._client);
  final SupabaseClient _client;

  String get _uid =>
      _client.auth.currentUser?.id ?? (throw StateError('not authenticated'));

  Future<Result<Plan>> createPlan({
    required String vibe,
    required String title,
    String? detail,
  }) async {
    try {
      final row = await _client
          .from('plans')
          .insert({'owner_id': _uid, 'vibe': vibe, 'title': title, if (detail != null) 'detail': detail})
          .select()
          .single();
      return Success(Plan.fromJson(row));
    } catch (_) {
      return const Failure("couldn't make the plan. try again?");
    }
  }

  Future<Result<Plan>> getByToken(String token) async {
    try {
      final row = await _client
          .from('plans')
          .select()
          .eq('share_token', token.trim())
          .single();
      return Success(Plan.fromJson(row));
    } catch (_) {
      return const Failure("plan not found. double-check the code?");
    }
  }

  Future<Result<PlanMember>> joinOrUpdate(String planId, String status) async {
    try {
      final row = await _client
          .from('plan_members')
          .upsert(
            {'plan_id': planId, 'user_id': _uid, 'status': status},
            onConflict: 'plan_id,user_id',
          )
          .select()
          .single();
      return Success(PlanMember.fromJson(row));
    } catch (_) {
      return const Failure("couldn't update ur rsvp.");
    }
  }

  Future<List<Plan>> myPlans() async {
    try {
      final owned = await _client
          .from('plans')
          .select()
          .eq('owner_id', _uid)
          .order('created_at', ascending: false);

      final memberRows = await _client
          .from('plan_members')
          .select('plan_id')
          .eq('user_id', _uid);

      final memberIds = (memberRows as List)
          .map((r) => r['plan_id'] as String)
          .toList();

      List<dynamic> joined = [];
      if (memberIds.isNotEmpty) {
        joined = await _client
            .from('plans')
            .select()
            .inFilter('id', memberIds)
            .neq('owner_id', _uid)
            .order('created_at', ascending: false);
      }

      return [
        ...owned.map((r) => Plan.fromJson(Map<String, dynamic>.from(r as Map))),
        ...joined.map((r) => Plan.fromJson(Map<String, dynamic>.from(r as Map))),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<Result<void>> deletePlan(String planId) async {
    try {
      await _client.from('plans').delete().eq('id', planId).eq('owner_id', _uid);
      return const Success(null);
    } catch (_) {
      return const Failure("couldn't cancel the plan. try again?");
    }
  }

  Future<List<PlanMember>> membersFor(String planId) async {
    try {
      final rows = await _client
          .from('plan_members')
          .select()
          .eq('plan_id', planId);
      return (rows as List).map((r) => PlanMember.fromJson(r as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<PlanMember?> myMembership(String planId) async {
    try {
      final rows = await _client
          .from('plan_members')
          .select()
          .eq('plan_id', planId)
          .eq('user_id', _uid);
      if ((rows as List).isEmpty) return null;
      return PlanMember.fromJson(rows.first);
    } catch (_) {
      return null;
    }
  }
}
