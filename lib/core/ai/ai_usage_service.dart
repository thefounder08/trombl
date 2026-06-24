import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fire-and-forget logger for every Gemini call.
/// Target metrics: <5 calls/user/day, >70% cache hit rate, 0 visible failures.
class AiUsageService {
  AiUsageService(this._client);
  final SupabaseClient _client;

  /// Log a Gemini call. Non-blocking — errors are swallowed silently.
  void log({
    required String endpoint, // 'menu' | 'decide' | 'response'
    required bool cacheHit,
    required int fallbackLayer, // 1=gemini live, 2=stale cache, 3=static
    int? promptChars,
    int? responseChars,
    int? durationMs,
  }) {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    _client.from('ai_usage').insert({
      'user_id': uid,
      'endpoint': endpoint,
      'cache_hit': cacheHit,
      'fallback_layer': fallbackLayer,
      'prompt_chars': ?promptChars,
      'response_chars': ?responseChars,
      'duration_ms': ?durationMs,
    }).then((_) {}).catchError((e) {
      debugPrint('[AiUsage] log error: $e');
    });
  }
}
