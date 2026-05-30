import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../../../shared/result.dart';
import '../domain/plan_models.dart';

/// Feature-level plan repository.
///
/// Exposes three methods required by the invite loop:
///  - [createPlan]   → creates a plan row and derives the share URL.
///  - [fetchByToken] → public fetch (no auth check), used by plan landing screen.
///  - [joinPlan]     → upserts a plan_members row for the signed-in user.
class FeaturePlanRepository {
  FeaturePlanRepository(this._client);
  final SupabaseClient _client;

  bool get _isSignedIn => _client.auth.currentUser != null;
  String get _uid => _client.auth.currentUser!.id;

  /// Creates a plan and returns the plan plus the shareable URL.
  Future<Result<({Plan plan, String shareUrl})>> createPlan({
    required String vibe,
    required String title,
    String? detail,
  }) async {
    try {
      final row = await _client
          .from('plans')
          .insert({
            'owner_id': _uid,
            'vibe': vibe,
            'title': title,
            if (detail != null) 'detail': detail,
          })
          .select()
          .single();
      final plan = Plan.fromJson(row);
      final shareUrl = 'https://trombl.netlify.app/p/${plan.shareToken}';
      return Success((plan: plan, shareUrl: shareUrl));
    } catch (_) {
      return const Failure("couldn't make the plan. try again?");
    }
  }

  /// Fetch a plan by its share token — no auth required.
  Future<Result<Plan>> fetchByToken(String token) async {
    try {
      final row = await _client
          .from('plans')
          .select()
          .eq('share_token', token.trim())
          .single();
      return Success(Plan.fromJson(row));
    } catch (_) {
      return const Failure("plan not found. double-check the link?");
    }
  }

  /// Upsert a plan_members row. [status] is "in" or "out".
  /// Caller must be signed in.
  Future<Result<PlanMember>> joinPlan(String planId, String status) async {
    if (!_isSignedIn) return const Failure("sign in first.");
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

  /// Fetch the current user's membership for [planId], or null.
  Future<PlanMember?> myMembership(String planId) async {
    if (!_isSignedIn) return null;
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
