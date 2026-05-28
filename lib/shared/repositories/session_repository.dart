import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../models/models.dart';
import '../result.dart';

/// Data access for sessions + picks. Repository pattern — no Supabase
/// calls leak into widgets or providers above this layer.
class SessionRepository {
  SessionRepository(this._client);
  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  /// Start a new day session with a chosen vibe.
  Future<Result<Session>> startSession(String vibe, {String? city}) async {
    try {
      final row = await _client
          .from('sessions')
          .insert({'user_id': _uid, 'vibe': vibe, 'city': city})
          .select()
          .single();
      return Success(Session.fromJson(row));
    } catch (_) {
      return const Failure("couldn't start ur day. try again?");
    }
  }

  /// Record a pick within a session.
  Future<Result<Pick>> addPick({
    required String sessionId,
    required String categoryId,
    required String optionId,
    required String label,
    required String tag,
  }) async {
    try {
      final row = await _client
          .from('picks')
          .insert({
            'session_id': sessionId,
            'user_id': _uid,
            'category_id': categoryId,
            'option_id': optionId,
            'label': label,
            'tag': tag,
          })
          .select()
          .single();
      return Success(Pick.fromJson(row));
    } catch (_) {
      return const Failure("trom didn't catch that. try again?");
    }
  }

  /// Mark a pick done/undone at check-in.
  Future<void> setPickDone(String pickId, bool done) async {
    await _client.from('picks').update({'done': done}).eq('id', pickId);
  }

  /// Wrap up a session.
  Future<void> wrapSession(String sessionId) async {
    await _client
        .from('sessions')
        .update({'wrapped_at': DateTime.now().toIso8601String()})
        .eq('id', sessionId);
  }

  /// Last [days] of sessions for the "trom's read on you" feature.
  Future<List<Session>> recentSessions({int days = 7}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await _client
        .from('sessions')
        .select()
        .eq('user_id', _uid)
        .gte('started_at', since.toIso8601String())
        .order('started_at', ascending: false);
    return (rows as List).map((r) => Session.fromJson(r)).toList();
  }

  /// Returns today's unwrapped session if one exists, null otherwise.
  Future<Session?> todaySession() async {
    try {
      final now = DateTime.now();
      final startOfDay =
          DateTime(now.year, now.month, now.day).toIso8601String();
      final rows = await _client
          .from('sessions')
          .select()
          .eq('user_id', _uid)
          .gte('started_at', startOfDay)
          .isFilter('wrapped_at', null)
          .order('started_at', ascending: false)
          .limit(1);
      if ((rows as List).isEmpty) return null;
      return Session.fromJson(rows.first);
    } catch (_) {
      return null;
    }
  }

  Future<List<Pick>> picksForSessions(List<String> sessionIds) async {
    if (sessionIds.isEmpty) return [];
    final rows =
        await _client.from('picks').select().inFilter('session_id', sessionIds);
    return (rows as List).map((r) => Pick.fromJson(r)).toList();
  }

  Future<Profile?> getProfile() async {
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', _uid)
          .single();
      return Profile.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateProfile({String? displayName, String? handle}) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['display_name'] = displayName;
    if (handle != null) data['handle'] = handle;
    if (data.isEmpty) return;
    await _client.from('profiles').upsert({'id': _uid, ...data});
  }

  Future<Map<String, Profile>> profilesForUsers(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('profiles')
          .select()
          .inFilter('id', userIds);
      return {
        for (final r in (rows as List))
          (r['id'] as String): Profile.fromJson(r as Map<String, dynamic>)
      };
    } catch (_) {
      return {};
    }
  }
}
