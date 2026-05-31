import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../../../shared/result.dart';
import '../domain/plan_models.dart';

typedef LandingData = ({
  Plan plan,
  String? ownerName,
  int memberCount,
  List<String> memberInitials,
  List<String> memberNames,
});

/// Feature-level plan repository.
class FeaturePlanRepository {
  FeaturePlanRepository(this._client);
  final SupabaseClient _client;

  bool get _isSignedIn => _client.auth.currentUser != null;
  String get _uid =>
      _client.auth.currentUser?.id ?? (throw StateError('not authenticated'));

  /// Creates a plan and returns the plan plus the shareable URL.
  Future<Result<({Plan plan, String shareUrl})>> createPlan({
    required String vibe,
    required String title,
    String?   detail,
    DateTime? startsAt,
    DateTime? expiresAt,
  }) async {
    try {
      final row = await _client
          .from('plans')
          .insert({
            'owner_id': _uid,
            'vibe': vibe,
            'title': title,
            if (detail    != null) 'detail':     detail,
            if (startsAt  != null) 'starts_at':  startsAt.toIso8601String(),
            if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
          })
          .select()
          .single();
      final plan = Plan.fromJson(row);
      // Auto-add owner as 'in' member so they appear in the who's-in list.
      await _client
          .from('plan_members')
          .upsert(
            {'plan_id': plan.id, 'user_id': _uid, 'status': 'in'},
            onConflict: 'plan_id,user_id',
          );
      final shareUrl = 'https://trombl.netlify.app/p/${plan.shareToken}';
      return Success((plan: plan, shareUrl: shareUrl));
    } catch (_) {
      return const Failure("couldn't make the plan. try again?");
    }
  }

  /// Fetch all data needed by the public plan landing page.
  /// Works for anonymous users — no auth required.
  Future<Result<LandingData>> fetchLandingData(String token) async {
    try {
      // 1. Fetch plan
      final planRow = await _client
          .from('plans')
          .select()
          .eq('share_token', token.trim())
          .single();
      final plan = Plan.fromJson(planRow);

      // 2. Fetch owner profile
      String? ownerName;
      try {
        final ownerRow = await _client
            .from('profiles')
            .select('display_name, handle')
            .eq('id', plan.ownerId)
            .maybeSingle();
        final dn = ownerRow?['display_name'] as String?;
        final handle = ownerRow?['handle'] as String?;
        ownerName = dn ?? (handle != null ? '@$handle' : null);
      } catch (_) {}

      // 3. Fetch 'in' members (up to 4) for social proof
      int memberCount = 0;
      final memberInitials = <String>[];
      final memberNames = <String>[];

      try {
        final memberRows = await _client
            .from('plan_members')
            .select('user_id')
            .eq('plan_id', plan.id)
            .eq('status', 'in')
            .limit(4);

        final userIds = (memberRows as List)
            .map((r) => r['user_id'] as String)
            .toList();
        memberCount = userIds.length;

        if (userIds.isNotEmpty) {
          final profileRows = await _client
              .from('profiles')
              .select('id, display_name, handle')
              .inFilter('id', userIds);

          // Preserve order: same order as plan_members query
          final profileMap = <String, Map<String, dynamic>>{
            for (final r in (profileRows as List))
              (r['id'] as String): r as Map<String, dynamic>,
          };

          for (final uid in userIds) {
            final p = profileMap[uid];
            final dn = p?['display_name'] as String?;
            final handle = p?['handle'] as String?;
            final name = dn ?? (handle != null ? '@$handle' : null);
            if (name != null) {
              memberInitials.add(name[0].toUpperCase());
              if (memberNames.length < 2) memberNames.add(name);
            }
          }
        }
      } catch (_) {
        // Member count is optional social proof — never block the page on it.
      }

      return Success((
        plan: plan,
        ownerName: ownerName,
        memberCount: memberCount,
        memberInitials: memberInitials,
        memberNames: memberNames,
      ));
    } catch (_) {
      return const Failure('gone');
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
