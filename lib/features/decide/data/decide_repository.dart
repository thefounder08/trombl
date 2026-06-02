import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../../../shared/models/models.dart';
import '../../../shared/repositories/session_repository.dart';
import '../domain/ai_pick_model.dart';

/// Context assembled before building the LLM prompt.
class DecideContext {
  const DecideContext({
    required this.sessionCount,
    required this.recentPicks,
    required this.recentSessions,
  });
  final int sessionCount;
  final List<AiPick> recentPicks;
  final List<Session> recentSessions;
}

class DecideRepository {
  DecideRepository(this._client, this._sessionRepo);
  final SupabaseClient _client;
  final SessionRepository _sessionRepo;

  String? get _uid => _client.auth.currentUser?.id;

  /// Persist a new AI pick to the DB. Returns the saved row (with server id),
  /// or the original pick if the insert fails (fallback safety).
  Future<AiPick> savePick(AiPick pick) async {
    final uid = _uid;
    if (uid == null) return pick;
    try {
      final row = await _client
          .from('ai_picks')
          .insert({
            'user_id': uid,
            if (pick.sessionId != null) 'session_id': pick.sessionId,
            'vibe': pick.vibe,
            'pick_text': pick.pickText,
            'reason_text': pick.reasonText,
            'tag': pick.tag,
            if (pick.moodText != null && pick.moodText!.isNotEmpty)
              'mood_text': pick.moodText,
            if (pick.pickHour != null) 'pick_hour': pick.pickHour,
            if (pick.pickDay != null) 'pick_day': pick.pickDay,
            if (pick.weatherCondition != null)
              'weather_condition': pick.weatherCondition,
          })
          .select()
          .single();
      return AiPick.fromJson(row);
    } catch (_) {
      return pick;
    }
  }

  Future<void> markRerolled(String pickId) async {
    if (pickId.isEmpty) return;
    try {
      await _client
          .from('ai_picks')
          .update({'rerolled': true}).eq('id', pickId);
    } catch (_) {}
  }

  Future<void> markAccepted(String pickId) async {
    if (pickId.isEmpty) return;
    try {
      await _client
          .from('ai_picks')
          .update({'accepted': true}).eq('id', pickId);
    } catch (_) {}
  }

  Future<List<AiPick>> recentAiPicks({int limit = 10}) async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from('ai_picks')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) => AiPick.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Load all history signals needed before building the pick prompt.
  Future<DecideContext> loadContext() async {
    try {
      final sessions = await _sessionRepo.recentSessions(days: 30);
      final picks = await recentAiPicks(limit: 10);
      return DecideContext(
        sessionCount: sessions.length,
        recentPicks: picks,
        recentSessions: sessions,
      );
    } catch (_) {
      return const DecideContext(
        sessionCount: 0,
        recentPicks: [],
        recentSessions: [],
      );
    }
  }
}
