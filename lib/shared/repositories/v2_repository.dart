import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/engine/archetype/archetype_models.dart';
import '../../core/engine/open_loops/open_loop_models.dart';

/// Data access for V2 engine tables.
///
/// All methods are graceful — if a table doesn't exist yet or the query
/// fails, they return empty/neutral values so the app never crashes.
///
/// Required Supabase tables (create with migration below):
///   - user_state        (mood, energy, social_battery, budget_level)
///   - open_loops        (title, status, priority, category)
///   - recommendation_log (recommendation, mode, score, accepted)
///   - action_history    (action_id, category, completed, ignored)
///
/// The archetype_scores column lives in the existing `profiles` table as
/// a jsonb column — add it with: ALTER TABLE profiles ADD COLUMN IF NOT
/// EXISTS archetype_scores jsonb DEFAULT '{}'::jsonb;
class V2Repository {
  V2Repository(this._client);
  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  // ─── Archetype scores ─────────────────────────────────────────────────────

  Future<ArchetypeScores> loadArchetypes() async {
    final uid = _uid;
    if (uid == null) return ArchetypeScores.neutral();
    try {
      final row = await _client
          .from('profiles')
          .select('archetype_scores')
          .eq('id', uid)
          .maybeSingle();
      final json = row?['archetype_scores'] as Map<String, dynamic>?;
      if (json == null) return ArchetypeScores.neutral();
      return ArchetypeScores.fromJson(json);
    } catch (e) {
      debugPrint('[V2Repo] loadArchetypes error: $e');
      return ArchetypeScores.neutral();
    }
  }

  Future<void> saveArchetypes(ArchetypeScores scores) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client.from('profiles').upsert({
        'id': uid,
        'archetype_scores': scores.toJson(),
      }, onConflict: 'id');
    } catch (e) {
      debugPrint('[V2Repo] saveArchetypes error: $e');
    }
  }

  // ─── Open loops ───────────────────────────────────────────────────────────

  Future<List<OpenLoop>> loadOpenLoops({int limit = 10}) async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from('open_loops')
          .select()
          .eq('user_id', uid)
          .eq('status', 'open')
          .order('priority', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) => OpenLoop.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[V2Repo] loadOpenLoops error: $e');
      return [];
    }
  }

  Future<OpenLoop?> addOpenLoop({
    required String title,
    int priority = 1,
    String? category,
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final row = await _client
          .from('open_loops')
          .insert({
            'user_id': uid,
            'title': title,
            'status': 'open',
            'priority': priority,
            'category': ?category,
          })
          .select()
          .single();
      return OpenLoop.fromJson(row);
    } catch (e) {
      debugPrint('[V2Repo] addOpenLoop error: $e');
      return null;
    }
  }

  Future<void> resolveOpenLoop(String loopId, {bool done = true}) async {
    try {
      await _client.from('open_loops').update({
        'status': done ? 'done' : 'ignored',
      }).eq('id', loopId);
    } catch (e) {
      debugPrint('[V2Repo] resolveOpenLoop error: $e');
    }
  }

  // ─── Recommendation log ───────────────────────────────────────────────────

  Future<void> logRecommendation({
    required String recommendation,
    required String mode,
    required double score,
    bool accepted = false,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client.from('recommendation_log').insert({
        'user_id': uid,
        'recommendation': recommendation,
        'mode': mode,
        'score': score,
        'accepted': accepted,
      });
    } catch (e) {
      debugPrint('[V2Repo] logRecommendation error: $e');
    }
  }

  /// Recent recommendation IDs (for diversity / anti-repeat).
  Future<List<String>> recentRecommendationIds({int limit = 10}) async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from('recommendation_log')
          .select('recommendation')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) => r['recommendation'] as String)
          .toList();
    } catch (e) {
      debugPrint('[V2Repo] recentRecommendations error: $e');
      return [];
    }
  }

  // ─── Action history ───────────────────────────────────────────────────────

  Future<void> recordAction({
    required String actionId,
    required String category,
    required bool completed,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client.from('action_history').insert({
        'user_id': uid,
        'action_id': actionId,
        'category': category,
        'completed': completed,
        'ignored': !completed,
      });
    } catch (e) {
      debugPrint('[V2Repo] recordAction error: $e');
    }
  }

  /// Accepted action tags — used to recompute archetype scores.
  Future<({List<String> accepted, List<String> rejected})>
      loadActionTagHistory({int limit = 50}) async {
    final uid = _uid;
    if (uid == null) {
      return (accepted: <String>[], rejected: <String>[]);
    }
    try {
      final rows = await _client
          .from('action_history')
          .select('action_id, completed')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);

      final accepted = <String>[];
      final rejected = <String>[];
      for (final row in rows as List) {
        final id = row['action_id'] as String;
        // Map action_id → tags via local library (no extra DB call needed)
        if (row['completed'] == true) {
          accepted.add(id);
        } else {
          rejected.add(id);
        }
      }
      return (accepted: accepted, rejected: rejected);
    } catch (e) {
      debugPrint('[V2Repo] loadActionTagHistory error: $e');
      return (accepted: <String>[], rejected: <String>[]);
    }
  }
}
