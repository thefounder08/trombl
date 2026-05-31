import 'ai_pick_model.dart';

/// Rules-based fallback picks — keyed by vibe + time bucket.
/// Activated when the LLM proxy is down or returns an unparseable response.
/// Scenario 5: the feature must survive an LLM outage.
abstract final class PickFallback {
  static AiPick get(String vibe, int hour, String? sessionId) {
    final bucket = _bucket(hour);
    final key = '${vibe}_$bucket';
    final data = _picks[key] ?? _picks['fomo_evening']!;
    return AiPick(
      id: '',
      userId: '',
      sessionId: sessionId,
      vibe: vibe,
      pickText: data.$1,
      reasonText: data.$2,
      tag: data.$3,
    );
  }

  static String _bucket(int hour) {
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 22) return 'evening';
    return 'latenight';
  }

  // (pickText, reasonText, tag)
  static const _picks = <String, (String, String, String)>{
    'fomo_morning': (
      'get outside for 20 minutes',
      'morning energy is free. spend it.',
      'solo',
    ),
    'fomo_afternoon': (
      'text someone you owe a reply',
      "afternoon slump? make someone's day instead.",
      'squad',
    ),
    'fomo_evening': (
      'leave the house — no plan, just go',
      "ur brain is lying to u. just go.",
      'solo',
    ),
    'fomo_latenight': (
      'find the nearest open spot on maps',
      "late but not dead. first result, don't scroll.",
      'discover',
    ),
    'jomo_morning': (
      'slow coffee, no screen for 20 min',
      'the morning asks for nothing. give it that.',
      'rest',
    ),
    'jomo_afternoon': (
      'one show, full episode, commit',
      'afternoon jomo is underrated. this is it.',
      'rest',
    ),
    'jomo_evening': (
      'order in, lights low, no plans',
      "that's the whole vibe. just execute it.",
      'order in',
    ),
    'jomo_latenight': (
      'phone down in 10. ur body needs it.',
      'jomo at midnight means actually resting.',
      'rest',
    ),
  };
}
