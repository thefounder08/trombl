import 'ai_pick_model.dart';

/// Rules-based fallback picks — keyed by vibe + time bucket.
/// Each bucket has 3 options; rerollCount rotates through them so rerolls
/// never return the same pick twice in a session.
///
/// CRITICAL: the fallback MUST also respect time rules. This fires when Gemini
/// fails — "go for a walk" at 2am is unacceptable even as a fallback.
/// deepnight (0–5am): wind-down ONLY — no outside, no people.
abstract final class PickFallback {
  static AiPick get(
    String vibe,
    int hour,
    String? sessionId, {
    int rerollCount = 0,
  }) {
    final bucket = _bucket(hour);
    final key = '${vibe}_$bucket';
    // If a bucket key is missing (shouldn't happen), fall through to jomo_deepnight
    // as the safest time-appropriate default rather than a potentially invalid pick.
    final options = _picks[key] ?? _picks['jomo_deepnight']!;
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
    if (hour >= 0 && hour < 5) return 'deepnight'; // 12am–5am: hard wind-down only
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 22) return 'evening';
    return 'latenight'; // 10pm–12am: winding down
  }

  static const _picks = <String, List<(String, String, String)>>{
    // ── 12am–5am: WIND DOWN ONLY. No outside. No people. ─────────────────────
    'fomo_deepnight': [
      ('box breathing, 4 counts each',        "ur nervous system is still wired. slow it down.",      'rest'),
      ('phone face down, lie in the dark',    'screens are why u can\'t sleep. actually try this.',   'rest'),
      ('boring podcast, close ur eyes',       'nothing exciting. that\'s literally the point.',        'rest'),
    ],
    'jomo_deepnight': [
      ('lights off, phone down, lie there',   'jomo at 3am means actually sleeping.',                 'rest'),
      ('make something warm, wind down',      'chamomile, tea, whatever. then actually rest.',         'solo'),
      ('one boring podcast then sleep',       'give ur brain something dull. it\'ll knock out.',       'rest'),
    ],

    // ── 5am–12pm: morning ─────────────────────────────────────────────────────
    'fomo_morning': [
      ('get outside for 20 minutes',          'morning energy is free. spend it.',                    'solo'),
      ('text someone, make actual plans',     'ur fingers work in the morning too.',                   'squad'),
      ('find a coffee spot and go',           'sitting at home is not the move right now.',            'discover'),
    ],
    'jomo_morning': [
      ('slow coffee, no screen for 20 min',   'the morning asks for nothing. give it that.',           'rest'),
      ('journal for 10 min before anything',  'brain dump before the day takes over.',                 'solo'),
      ('one podcast or album, front to back', 'morning with good audio is a win.',                    'rest'),
    ],

    // ── 12pm–5pm: afternoon ───────────────────────────────────────────────────
    'fomo_afternoon': [
      ('text someone you owe a reply',        "afternoon slump? make someone's day instead.",         'squad'),
      ('step outside for 15 min, no phone',   'midday reset. do it before u talk urself out.',         'solo'),
      ('look up one thing happening tonight', 'future u will thank present u.',                       'discover'),
    ],
    'jomo_afternoon': [
      ('one show, full episode, commit',      'afternoon jomo is underrated. this is it.',             'rest'),
      ('order something u actually want',     'afternoon treat. u deserve it.',                        'order in'),
      ('lie down, no phone, 20 min',          'not napping, just horizontal. valid.',                  'rest'),
    ],

    // ── 5pm–10pm: evening ─────────────────────────────────────────────────────
    'fomo_evening': [
      ('leave the house — no plan, just go',  "ur brain is lying to u. just go.",                    'solo'),
      ('text the group chat right now',       'someone else is also waiting for this text.',           'squad'),
      ('find the closest bar on maps',        "first result. don't overthink it.",                    'discover'),
    ],
    'jomo_evening': [
      ('order in, lights low, no plans',      "that's the whole vibe. just execute it.",              'order in'),
      ('pick one show and commit to it',      "no scrolling for 30 min. just pick.",                  'rest'),
      ('bath or shower, full ritual',         'evening reset. ur body will thank u.',                  'rest'),
    ],

    // ── 10pm–12am: late night (winding down, not deep night) ─────────────────
    'fomo_latenight': [
      ('find the nearest open spot on maps',  "late but not dead. first result, don't scroll.",       'discover'),
      ('one last thing, then head home',      'late fomo is real. do ONE thing then close out.',       'solo'),
      ('light text — low-key hangout only',   "if someone's awake, keep it chill.",                   'squad'),
    ],
    'jomo_latenight': [
      ('phone down in 10. ur body needs it.', 'jomo at midnight means actually resting.',              'rest'),
      ('one more episode then sleep for real', "u said one more 3 eps ago. this time mean it.",        'rest'),
      ('make something warm and wind down',   'midnight tea energy. do it.',                           'solo'),
    ],
  };
}
