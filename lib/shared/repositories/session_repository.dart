import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../models/models.dart';
import '../result.dart';

/// Data access for sessions + picks. Repository pattern — no Supabase
/// calls leak into widgets or providers above this layer.
class SessionRepository {
  SessionRepository(this._client);
  final SupabaseClient _client;

  String get _uid =>
      _client.auth.currentUser?.id ?? (throw StateError('not authenticated'));

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

  /// Flip the vibe on an existing session.
  Future<void> switchVibe(String sessionId, String newVibe) async {
    await _client
        .from('sessions')
        .update({'vibe': newVibe})
        .eq('id', sessionId);
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
    try {
      final since = DateTime.now().subtract(Duration(days: days));
      final rows = await _client
          .from('sessions')
          .select()
          .eq('user_id', _uid)
          .gte('started_at', since.toIso8601String())
          .order('started_at', ascending: false);
      return (rows as List).map((r) => Session.fromJson(r)).toList();
    } catch (_) {
      return [];
    }
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
        await _client.from('picks').select().inFilter('session_id', sessionIds).order('created_at', ascending: false);
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

  Future<void> updateProfile({
    String? displayName,
    String? handle,
    String? city,
    String? lifestyle,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (displayName != null) data['display_name'] = displayName;
      if (handle != null) data['handle'] = handle;
      if (city != null) data['city'] = city;
      if (lifestyle != null) data['lifestyle'] = lifestyle;
      if (data.isEmpty) return;
      await _client.from('profiles').upsert({'id': _uid, ...data});
    } catch (_) {}
  }

  /// OAuth-sourced profile fields (`avatar_url`, `email`, `auth_provider`) —
  /// written via a *separate* upsert from [updateProfile] deliberately: if
  /// these columns aren't migrated onto `profiles` yet, this call fails on
  /// its own without taking the always-safe display_name/handle/city/
  /// lifestyle write down with it (a single upsert request fails as one
  /// unit in Postgres — mixing a maybe-missing column into the same call
  /// as guaranteed-existing ones would risk losing both).
  Future<void> updateOAuthProfileFields({
    String? avatarUrl,
    String? email,
    String? authProvider,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (avatarUrl != null) data['avatar_url'] = avatarUrl;
      if (email != null) data['email'] = email;
      if (authProvider != null) data['auth_provider'] = authProvider;
      if (data.isEmpty) return;
      await _client.from('profiles').upsert({'id': _uid, ...data});
    } catch (_) {}
  }

  Future<void> saveOnboardingData({
    required List<String> goals,
    required String archetype,
    required String scheduleType,
    required String weekendPref,
    required List<String> wantsMore,
  }) async {
    try {
      await _client.from('profiles').upsert({
        'id': _uid,
        'goals': goals,
        'archetype': archetype,
        'schedule_type': scheduleType,
        'weekend_pref': weekendPref,
        'wants_more': wantsMore,
        'onboarding_completed': true,
      });
    } catch (_) {}
  }

  /// Save a memory node trom generated about the user.
  Future<void> saveMemoryNode({
    required String type,
    required String content,
    double relevanceScore = 0.7,
    bool touchLastAccessed = false,
  }) async {
    try {
      await _client.from('memory_nodes').insert({
        'user_id': _uid,
        'type': type,
        'content': content,
        'relevance_score': relevanceScore,
        if (touchLastAccessed)
          'last_accessed': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Read a single saved preference by key.
  /// Looks for a memory_node where type='preference' and content starts with
  /// '[key]:'. Returns the value after the colon, or null if not found.
  Future<String?> readPreference(String key) async {
    try {
      final rows = await _client
          .from('memory_nodes')
          .select()
          .eq('user_id', _uid)
          .eq('type', 'preference')
          .ilike('content', '$key:%')
          .order('created_at', ascending: false)
          .limit(1);
      if ((rows as List).isEmpty) return null;
      final content = rows.first['content'] as String;
      final colonIdx = content.indexOf(':');
      if (colonIdx == -1) return null;
      final value = content.substring(colonIdx + 1).trim();
      // Guard against junk values that were mistakenly stored instead of
      // the real answer (e.g. "saved") — treat as not-yet-set.
      if (value.isEmpty || const {'saved', 'null', 'none', 'n/a'}.contains(value.toLowerCase())) {
        return null;
      }
      return value;
    } catch (_) {
      return null;
    }
  }

  /// Fetch recent memory nodes, newest first.
  Future<List<MemoryNode>> recentMemoryNodes({int limit = 5}) async {
    try {
      final rows = await _client
          .from('memory_nodes')
          .select()
          .eq('user_id', _uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) => MemoryNode.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
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
