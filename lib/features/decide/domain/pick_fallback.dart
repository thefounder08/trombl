import 'ai_pick_model.dart';

/// Rules-based fallback picks — keyed by vibe + time bucket.
/// Each bucket has 3 options; rerollCount rotates through them so rerolls
/// never return the same pick twice in a session.
/// Scenario 5: the feature must survive an LLM outage.
abstract final class PickFallback {
  static AiPick get(
    String vibe,
    int hour,
    String? sessionId, {
    int rerollCount = 0,
  }) {
    final bucket = _bucket(hour);
    final key = '${vibe}_$bucket';
    final options = _picks[key] ?? _picks['fomo_evening']!;
    final data = options[rerollCount % options.length];
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

  // Each entry is a list of 3 (pickText, reasonText, tag) tuples.
  static const _picks =
      <String, List<(String, String, String)>>{
    'fomo_morning': [
      ('get outside for 20 minutes',       'morning energy is free. spend it.',           'solo'),
      ('text someone, make actual plans',   'ur fingers work in the morning too.',         'squad'),
      ('find a coffee spot and actually go','sitting at home is not the move right now.',  'discover'),
    ],
    'fomo_afternoon': [
      ('text someone you owe a reply',      "afternoon slump? make someone's day instead.", 'squad'),
      ('step outside for 15 min, no phone', 'midday reset. do it before u talk urself out.','solo'),
      ('look up one thing happening tonight','future u will thank present u.',              'discover'),
    ],
    'fomo_evening': [
      ('leave the house — no plan, just go', "ur brain is lying to u. just go.",           'solo'),
      ('text the group chat right now',      'someone else is also waiting for this text.', 'squad'),
      ('find the closest bar on maps, go',   "first result. don't overthink it.",           'discover'),
    ],
    'fomo_latenight': [
      ('find the nearest open spot on maps', "late but not dead. first result, don't scroll.", 'discover'),
      ('text one person, see what happens',  "it's late but someone's awake.",               'squad'),
      ('walk for 20 min, wherever',          'night walks are underrated. go.',              'solo'),
    ],
    'jomo_morning': [
      ('slow coffee, no screen for 20 min',  'the morning asks for nothing. give it that.',  'rest'),
      ('journal for 10 min before anything', "brain dump before the day takes over.",        'solo'),
      ('one podcast or album, front to back', 'morning with good audio is a win.',           'rest'),
    ],
    'jomo_afternoon': [
      ('one show, full episode, commit',     'afternoon jomo is underrated. this is it.',   'rest'),
      ('order something u actually want',    "afternoon treat. u deserve it.",              'order in'),
      ('lie down, no phone, 20 min',         'not napping, just horizontal. valid.',        'rest'),
    ],
    'jomo_evening': [
      ('order in, lights low, no plans',     "that's the whole vibe. just execute it.",     'order in'),
      ('pick one show and commit to it',      "no scrolling netflix for 30 min. just pick.", 'rest'),
      ('bath or shower, full ritual',         'evening reset. ur body will thank u.',        'rest'),
    ],
    'jomo_latenight': [
      ('phone down in 10. ur body needs it.', 'jomo at midnight means actually resting.',   'rest'),
      ('one more episode then actually sleep', "u said one more 3 eps ago. this time mean it.", 'rest'),
      ('make something warm and wind down',   'midnight tea energy. do it.',                'solo'),
    ],
  };
}
