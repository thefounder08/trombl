import 'ai_pick_model.dart';

/// Rules-based fallback picks — keyed by vibe + time bucket.
/// 8 options per bucket. get() filters out already-shown picks so the user
/// never sees the same suggestion twice in a session.
///
/// CRITICAL: fallback must respect time rules. deepnight (0–5am): rest ONLY.
abstract final class PickFallback {
  static AiPick get(
    String vibe,
    int hour,
    String? sessionId, {
    int rerollCount = 0,
    List<String> exclude = const [],
  }) {
    final bucket = _bucket(hour);
    final key = '${vibe}_$bucket';
    final options = _picks[key] ?? _picks['jomo_deepnight']!;

    // Filter already-shown picks so rerolls never repeat.
    final available = options
        .where((o) => !exclude.any(
            (e) => e.toLowerCase().trim() == o.$1.toLowerCase().trim()))
        .toList();
    final pool = available.isNotEmpty ? available : options;

    final data = pool[rerollCount % pool.length];
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
    if (hour >= 0 && hour < 5) return 'deepnight';
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 22) return 'evening';
    return 'latenight';
  }

  static const _picks = <String, List<(String, String, String)>>{
    // ── 12am–5am: wind down only. no outside. no people. ─────────────────────
    'fomo_deepnight': [
      ('box breathing, 4 counts each',          "ur nervous system is still wired. slow it.",           'rest'),
      ('phone face down, lie in the dark',       'screens are why u can\'t sleep. actually try this.',   'rest'),
      ('boring podcast, eyes closed',            'nothing exciting. that\'s literally the point.',        'rest'),
      ('body scan — head to toe, slow',          'ur body\'s still tense. work through it.',             'rest'),
      ('write down what\'s looping in ur head',  '3am brain dump actually works. try it.',               'focus'),
      ('cold water, sit somewhere dark',         'basic reset. sometimes that\'s all it takes.',          'rest'),
      ('slow stretch then lie still',            'tired muscles stop buzzing faster.',                   'rest'),
      ('open something boring, let it play',     'ur brain needs dull right now. give it that.',         'rest'),
    ],
    'jomo_deepnight': [
      ('lights off, phone down, just lie there', 'jomo at 3am means actually sleeping.',                 'rest'),
      ('make something warm, slow wind-down',    'tea, chamomile, whatever. then rest.',                 'rest'),
      ('boring podcast on, close ur eyes',       'give ur brain something dull. it\'ll knock out.',      'rest'),
      ('write in ur notes for 5 mins',           'tired but wired? brain dump. then put it down.',       'focus'),
      ('body scan, no moving at all',            'deepnight jomo is lying still and letting go.',        'rest'),
      ('long boring video, let it run',          'background noise helps the brain switch off.',         'rest'),
      ('close everything. just dark and quiet.', 'the day is done. actually let it be.',                 'rest'),
      ('stretch properly then get into bed',     'moving first makes the stillness easier.',             'rest'),
    ],

    // ── 5am–12pm: morning ─────────────────────────────────────────────────────
    'fomo_morning': [
      ('grab a coffee and take the long way',    'morning window closes fast. use it.',                  'focus'),
      ('lock in actual plans with someone today','morning brain is clearer. set something up now.',       'social'),
      ('walk somewhere new, no set route',       'different route breaks the autopilot.',                'focus'),
      ('put something loud on and do the thing', 'morning with music hits different.',                   'focus'),
      ('make breakfast slow — no phone at all',  '15 mins of calm before the day takes over.',           'rest'),
      ('set a 25-min focus block right now',     'morning sharpness is real. use it before it\'s gone.', 'focus'),
      ('text one person u haven\'t in a while',  'morning is when people actually reply.',               'social'),
      ('plan what tonight looks like — now',     'morning version of u makes better decisions.',         'social'),
    ],
    'jomo_morning': [
      ('slow coffee, no screen for 20 min',      'the morning asks for nothing. give it that.',          'rest'),
      ('journal for 10 min before anything',     'brain dump before the day takes over.',                'focus'),
      ('one album front to back while u eat',    'morning with good audio is a win.',                   'rest'),
      ('make breakfast with zero distractions',  'ur phone can wait 20 mins. it\'ll be fine.',           'focus'),
      ('read something real — not the news',     'morning brain absorbs things differently.',            'focus'),
      ('slow stretch or yoga, 15 mins',          'jomo morning means starting on ur own terms.',         'rest'),
      ('plan ur day in 10 mins before anything', 'saves 2 hours of drift later.',                       'focus'),
      ('sit with ur coffee and look outside',    'no phone. just exist for a bit.',                     'rest'),
    ],

    // ── 12pm–5pm: afternoon ───────────────────────────────────────────────────
    'fomo_afternoon': [
      ('text someone and lock in plans tonight', 'afternoon clarity is rare. use it.',                   'social'),
      ('walk somewhere with an actual destination','midday reset — do it before u talk urself out.',      'focus'),
      ('look up one thing happening tonight',    'future u will thank present u.',                       'explore'),
      ('voice note someone instead of texting',  'way more interesting than just typing it out.',         'social'),
      ('find somewhere different to work from',  'different environment hits different. try it.',         'explore'),
      ('plan something for this weekend now',    'afternoon clarity. lock something in.',                 'social'),
      ('order food u actually want right now',   'stop thinking about it. just order.',                  'food'),
      ('45-min focus block — full commit',       'afternoon dip is a myth if u just start.',             'focus'),
    ],
    'jomo_afternoon': [
      ('one episode, full commit — no pausing',  'afternoon jomo is underrated. this is it.',            'rest'),
      ('order ur comfort food, eat it properly', 'no phone while eating. actual treat.',                 'food'),
      ('lie down, no phone, 20 min flat',        'not napping — just horizontal. valid.',                'rest'),
      ('slow snack and something good on',       'no rushing, no plans. that\'s the vibe.',              'rest'),
      ('clean one thing that\'s been annoying u','satisfying in a way u won\'t expect.',                 'focus'),
      ('long shower — the full ritual version',  '3pm reset. ur body will thank u.',                    'rest'),
      ('read for an hour, no interruptions',     'afternoon reading hits different.',                    'focus'),
      ('comfort playlist, do absolutely nothing','jomo afternoon at its best.',                          'rest'),
    ],

    // ── 5pm–10pm: evening ─────────────────────────────────────────────────────
    'fomo_evening': [
      ('leave the house — no plan, just go',     "ur brain is lying to u. just go.",                    'explore'),
      ('text the group chat right now',           'someone else is waiting for that text too.',           'social'),
      ('nearest spot on maps — first result, go', 'don\'t overthink it. first one. go.',                 'explore'),
      ('lock in evening plans in the next 10 min','window\'s closing. do it now.',                       'social'),
      ('find a live event or gig on tonight',     'something\'s always on. u just haven\'t looked.',     'explore'),
      ('call someone — don\'t just text',         'voice hits different. someone will pick up.',         'social'),
      ('book dinner somewhere u haven\'t tried',  'evening energy is for new things.',                   'food'),
      ('get dressed and leave. figure it out outside','best evenings start with just leaving.',           'explore'),
    ],
    'jomo_evening': [
      ('order in, lights low, no plans at all',   "that's the whole vibe. just execute it.",             'food'),
      ('pick one show and actually commit',        'no scrolling. pick and watch. done.',                 'rest'),
      ('bath or shower — full ritual',             'evening reset. ur body will thank u.',                'rest'),
      ('make a proper meal, take ur time',         'jomo evening with actual cooking is different.',     'food'),
      ('dim the lights and read for an hour',      'this is what evenings are actually for.',            'rest'),
      ('full skincare or grooming routine',        'treat urself like u matter. do the whole thing.',    'rest'),
      ('no-phone hour starting right now',         'jomo is actually resting. start now.',               'rest'),
      ('sort one low-effort thing that\'s pending','jomo doesn\'t mean lazy. small wins count.',         'focus'),
    ],

    // ── 10pm–12am: late night ─────────────────────────────────────────────────
    'fomo_latenight': [
      ('last call — find what\'s still open near u','late but not dead. go.',                            'explore'),
      ('one last thing then actually go home',     'do ONE thing and close out.',                        'focus'),
      ('voice note someone, see if they\'re up',   'someone\'s always awake.',                           'social'),
      ('quick check — anything on near u?',         'if it\'s happening, it\'s happening.',               'explore'),
      ('one more hour then leave. set the limit.',  'ur night self lies. be specific.',                  'focus'),
      ('late walk — city feels different now',      'everything looks different after midnight.',          'focus'),
      ('find a late diner or late-night spot',      'best conversations happen late.',                    'food'),
      ('text ur person — what\'s the late move?',   'someone has a plan. find them.',                   'social'),
    ],
    'jomo_latenight': [
      ('phone down in 10. ur body needs this.',    'jomo at midnight means actually resting.',            'rest'),
      ('one more episode then sleep — for real',   'u said one more 3 eps ago. mean it.',                'rest'),
      ('make something warm and slow down',        'midnight tea. actually do it.',                       'rest'),
      ('tidy ur space for 10 min then rest',       'clear space = clearer sleep.',                       'focus'),
      ('3 things that happened today — write it',  'close the loop before sleep.',                       'focus'),
      ('full skincare routine then lights out',    'ritual signals sleep. ur brain responds to it.',     'rest'),
      ('phone across the room, something calming on','if it\'s next to u, u won\'t sleep.',              'rest'),
      ('read something easy until u drop off',     'best way to knock out. no screens.',                 'rest'),
    ],
  };
}
