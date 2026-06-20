import 'menu_models.dart';

/// All menu content — 4 core categories + 1 new-drop per vibe.
/// Labels are taken verbatim from the prototype.
abstract final class TromblMenu {
  // ─── FOMO ────────────────────────────────────────────────────────────────────

  static const _fomoCore = <MenuCategory>[
    MenuCategory(
      id: 'f1', emoji: '🎉', title: 'go out tonight',
      sub: "something's happening. be there.",
      options: [
        MenuOption(id: 'f1a', label: 'rooftop or house party',              tag: 'squad'),
        MenuOption(id: 'f1b', label: 'live music or gig',                   tag: 'discover'),
        MenuOption(id: 'f1c', label: 'bar hop with the crew',               tag: 'squad'),
        MenuOption(id: 'f1d', label: 'club / dance floor',                  tag: 'discover'),
      ],
    ),
    MenuCategory(
      id: 'f2', emoji: '👥', title: 'make plans w someone',
      sub: "u've been saying 'soon' for too long.",
      options: [
        MenuOption(id: 'f2a', label: 'text the group chat rn',                   tag: 'squad'),
        MenuOption(id: 'f2b', label: 'reach out to that one person',             tag: 'squad'),
        MenuOption(id: 'f2c', label: "game night at someone's place",            tag: 'coming soon'),
        MenuOption(id: 'f2d', label: 'find something random and drag everyone',  tag: 'coming soon'),
      ],
    ),
    MenuCategory(
      id: 'f3', emoji: '💸', title: 'treat urself',
      sub: "u deserve it and u know it.",
      options: [
        MenuOption(id: 'f3a', label: 'fancy dinner, main character era',          tag: 'discover'),
        MenuOption(id: 'f3b', label: 'book a concert or show',                    tag: 'discover'),
        MenuOption(id: 'f3c', label: 'get ur hair or nails done',                 tag: 'discover'),
        MenuOption(id: 'f3d', label: 'do something the future-you will remember', tag: 'coming soon'),
      ],
    ),
    MenuCategory(
      id: 'f4', emoji: '📸', title: 'make or post something',
      sub: "the timeline needs u.",
      options: [
        MenuOption(id: 'f4a', label: 'instagram post or story',           tag: 'content'),
        MenuOption(id: 'f4b', label: 'shoot a reel or vlog',              tag: 'content'),
        MenuOption(id: 'f4c', label: 'drop a new spotify playlist',       tag: 'content'),
        MenuOption(id: 'f4d', label: 'post ur honest opinion on something', tag: 'coming soon'),
      ],
    ),
  ];

  static const _fomoNewDrop = MenuCategory(
    id: 'fnew', emoji: '🏃', title: 'move ur body',
    sub: "physical fomo is real too. ur missing out on endorphins.",
    isNewDrop: true,
    options: [
      MenuOption(id: 'fn1', label: 'gym session — actually go',              tag: 'discover'),
      MenuOption(id: 'fn2', label: 'group fitness class (pilates, boxing)',   tag: 'coming soon'),
      MenuOption(id: 'fn3', label: 'look up outdoor things happening today',  tag: 'coming soon'),
      MenuOption(id: 'fn4', label: 'hike or trail',                           tag: 'coming soon'),
    ],
  );

  // ─── JOMO ────────────────────────────────────────────────────────────────────

  static const _jomoCore = <MenuCategory>[
    MenuCategory(
      id: 'j1', emoji: '🛌', title: 'fully rot today',
      sub: "no guilt. ur recharging. this is valid.",
      options: [
        MenuOption(id: 'j1a', label: 'watch something new',              tag: 'rest'),
        MenuOption(id: 'j1b', label: 'endless videos',                    tag: 'rest'),
        MenuOption(id: 'j1c', label: 'sleep in or nap aggressively',     tag: 'rest'),
        MenuOption(id: 'j1d', label: 'do absolutely nothing',            tag: 'rest'),
      ],
    ),
    MenuCategory(
      id: 'j2', emoji: '🍕', title: 'comfort food situation',
      sub: "let the food come to u. u earned it.",
      options: [
        MenuOption(id: 'j2a', label: 'ur usual from that one place',         tag: 'order in'),
        MenuOption(id: 'j2b', label: 'full snack spread, no actual meals',   tag: 'order in'),
        MenuOption(id: 'j2c', label: 'bake something (therapeutic fr)',      tag: 'rest'),
        MenuOption(id: 'j2d', label: 'make a fancy coffee and sit with it',  tag: 'rest'),
      ],
    ),
    MenuCategory(
      id: 'j3', emoji: '✨', title: 'soft recharge',
      sub: "the quiet stuff that actually fills u up.",
      options: [
        MenuOption(id: 'j3a', label: 'do a full face mask and decompress',   tag: 'rest'),
        MenuOption(id: 'j3b', label: 'journal or full brain dump',           tag: 'content'),
        MenuOption(id: 'j3c', label: 'long shower or bath — full ritual',    tag: 'rest'),
        MenuOption(id: 'j3d', label: 'clean and organise ur space',          tag: 'coming soon'),
      ],
    ),
    MenuCategory(
      id: 'j4', emoji: '💭', title: 'get in ur head',
      sub: "ur alone time is actually ur superpower.",
      options: [
        MenuOption(id: 'j4a', label: 'write down everything on ur mind',     tag: 'content'),
        MenuOption(id: 'j4b', label: 'vision board ur next 6 months',        tag: 'coming soon'),
        MenuOption(id: 'j4c', label: 'reflect on the last month honestly',   tag: 'coming soon'),
        MenuOption(id: 'j4d', label: 'write a letter to ur future self',     tag: 'coming soon'),
      ],
    ),
  ];

  static const _jomoNewDrop = MenuCategory(
    id: 'jnew', emoji: '🎧', title: 'get lost in music',
    sub: "ur ears deserve a full uninterrupted day.",
    isNewDrop: true,
    options: [
      MenuOption(id: 'jn1', label: 'full album, front to back',              tag: 'rest'),
      MenuOption(id: 'jn2', label: 'build a new playlist from scratch',      tag: 'coming soon'),
      MenuOption(id: 'jn3', label: 'find a completely new artist',           tag: 'coming soon'),
      MenuOption(id: 'jn4', label: 'podcast deep dive on something random',  tag: 'coming soon'),
    ],
  );

  // ─── Time-aware Layer 3 static categories ────────────────────────────────────

  static const _earlyMorningCore = <MenuCategory>[
    MenuCategory(id: 'em1', emoji: '☀️', title: 'wake up properly', sub: 'ur body needs a minute.',
      options: [
        MenuOption(id: 'em1a', label: 'sunlight first, phone second', tag: 'solo'),
        MenuOption(id: 'em1b', label: 'slow coffee, no scrolling', tag: 'rest'),
        MenuOption(id: 'em1c', label: 'open the window and breathe', tag: 'rest'),
        MenuOption(id: 'em1d', label: '5 minutes outside', tag: 'solo'),
      ]),
    MenuCategory(id: 'em2', emoji: '🥣', title: 'breakfast first', sub: 'ur brain runs on food.',
      options: [
        MenuOption(id: 'em2a', label: 'make something warm', tag: 'solo'),
        MenuOption(id: 'em2b', label: 'find a spot nearby', tag: 'discover'),
        MenuOption(id: 'em2c', label: 'proper meal, no excuses', tag: 'solo'),
        MenuOption(id: 'em2d', label: 'order ur fave breakfast in', tag: 'order in'),
      ]),
    MenuCategory(id: 'em3', emoji: '🏃', title: 'move ur body', sub: 'morning energy is free.',
      options: [
        MenuOption(id: 'em3a', label: 'quick walk outside', tag: 'solo'),
        MenuOption(id: 'em3b', label: 'stretch for 10 minutes', tag: 'rest'),
        MenuOption(id: 'em3c', label: 'gym session before it fills up', tag: 'discover'),
        MenuOption(id: 'em3d', label: 'whatever gets u breathing', tag: 'solo'),
      ]),
    MenuCategory(id: 'em4', emoji: '🧠', title: 'set the tone', sub: 'the first hour decides the day.',
      options: [
        MenuOption(id: 'em4a', label: 'write down 3 things', tag: 'content'),
        MenuOption(id: 'em4b', label: 'one small thing done', tag: 'solo'),
        MenuOption(id: 'em4c', label: 'no phone for 20 min', tag: 'rest'),
        MenuOption(id: 'em4d', label: 'check in with someone', tag: 'squad'),
      ]),
  ];

  static const _workdayCore = <MenuCategory>[
    MenuCategory(id: 'wk1', emoji: '⚡', title: 'focus sprint', sub: 'one thing, full send.',
      options: [
        MenuOption(id: 'wk1a', label: 'timer on, everything off', tag: 'solo'),
        MenuOption(id: 'wk1b', label: 'one task, start to finish', tag: 'solo'),
        MenuOption(id: 'wk1c', label: 'inbox zero, just one folder', tag: 'solo'),
        MenuOption(id: 'wk1d', label: "write the thing u've been avoiding", tag: 'content'),
      ]),
    MenuCategory(id: 'wk2', emoji: '🍱', title: 'proper lunch', sub: 'step away. actually eat.',
      options: [
        MenuOption(id: 'wk2a', label: 'away from the desk — non-negotiable', tag: 'solo'),
        MenuOption(id: 'wk2b', label: 'order something proper', tag: 'order in'),
        MenuOption(id: 'wk2c', label: 'find a spot 5 min away', tag: 'discover'),
        MenuOption(id: 'wk2d', label: 'lunch with someone', tag: 'squad'),
      ]),
    MenuCategory(id: 'wk3', emoji: '🚶', title: 'touch grass', sub: '15 min. ur brain needs it.',
      options: [
        MenuOption(id: 'wk3a', label: 'walk around the block', tag: 'solo'),
        MenuOption(id: 'wk3b', label: 'sit outside for 10 min', tag: 'rest'),
        MenuOption(id: 'wk3c', label: 'coffee run, walk both ways', tag: 'discover'),
        MenuOption(id: 'wk3d', label: 'find a bench', tag: 'solo'),
      ]),
    MenuCategory(id: 'wk4', emoji: '📋', title: 'finish strong', sub: "the day isn't done yet.",
      options: [
        MenuOption(id: 'wk4a', label: 'clear the blocker', tag: 'solo'),
        MenuOption(id: 'wk4b', label: 'send the thing u owe', tag: 'squad'),
        MenuOption(id: 'wk4c', label: "write tomorrow's top 3", tag: 'content'),
        MenuOption(id: 'wk4d', label: 'hydrate + 10 min reset', tag: 'rest'),
      ]),
  ];

  static const _primeTimeCore = <MenuCategory>[
    MenuCategory(id: 'pt1', emoji: '🎉', title: 'make something happen', sub: 'tonight is happening.',
      options: [
        MenuOption(id: 'pt1a', label: 'text the group chat rn', tag: 'squad'),
        MenuOption(id: 'pt1b', label: 'find something nearby', tag: 'discover'),
        MenuOption(id: 'pt1c', label: 'just leave the house', tag: 'solo'),
        MenuOption(id: 'pt1d', label: 'event tonight?', tag: 'discover'),
      ]),
    MenuCategory(id: 'pt2', emoji: '👥', title: 'text someone', sub: "u've been quiet long enough.",
      options: [
        MenuOption(id: 'pt2a', label: 'group chat is waiting', tag: 'squad'),
        MenuOption(id: 'pt2b', label: 'dm that one person', tag: 'squad'),
        MenuOption(id: 'pt2c', label: 'check on a friend', tag: 'squad'),
        MenuOption(id: 'pt2d', label: 'make actual plans', tag: 'squad'),
      ]),
    MenuCategory(id: 'pt3', emoji: '🏃', title: 'move ur body', sub: 'evening energy is different.',
      options: [
        MenuOption(id: 'pt3a', label: 'evening run or walk', tag: 'solo'),
        MenuOption(id: 'pt3b', label: 'gym before it closes', tag: 'discover'),
        MenuOption(id: 'pt3c', label: 'stretch after the day', tag: 'rest'),
        MenuOption(id: 'pt3d', label: 'class near u', tag: 'discover'),
      ]),
    MenuCategory(id: 'pt4', emoji: '🎬', title: 'enjoy tonight', sub: "that's literally the whole job.",
      options: [
        MenuOption(id: 'pt4a', label: 'order in, lights down', tag: 'order in'),
        MenuOption(id: 'pt4b', label: 'dinner out', tag: 'discover'),
        MenuOption(id: 'pt4c', label: 'movie or show, commit', tag: 'rest'),
        MenuOption(id: 'pt4d', label: 'whatever tonight version of u wants', tag: 'solo'),
      ]),
  ];

  static const _windDownCore = <MenuCategory>[
    MenuCategory(id: 'wd1', emoji: '📖', title: 'slow down', sub: 'ur nervous system is still wired.',
      options: [
        MenuOption(id: 'wd1a', label: 'no more screens after this', tag: 'rest'),
        MenuOption(id: 'wd1b', label: 'read actual pages', tag: 'rest'),
        MenuOption(id: 'wd1c', label: 'journaling or brain dump', tag: 'content'),
        MenuOption(id: 'wd1d', label: 'stretching or breathing', tag: 'rest'),
      ]),
    MenuCategory(id: 'wd2', emoji: '🛏', title: 'sleep wins', sub: "ur future self will thank u.",
      options: [
        MenuOption(id: 'wd2a', label: 'phone face down now', tag: 'rest'),
        MenuOption(id: 'wd2b', label: 'boring podcast, close ur eyes', tag: 'rest'),
        MenuOption(id: 'wd2c', label: 'box breathing, 4 counts', tag: 'rest'),
        MenuOption(id: 'wd2d', label: 'lights off, commit to sleep', tag: 'rest'),
      ]),
    MenuCategory(id: 'wd3', emoji: '🧠', title: 'clear ur head', sub: 'process before u crash.',
      options: [
        MenuOption(id: 'wd3a', label: "write what's on ur mind", tag: 'content'),
        MenuOption(id: 'wd3b', label: 'reflect on today honestly', tag: 'solo'),
        MenuOption(id: 'wd3c', label: 'one thing for tomorrow', tag: 'solo'),
        MenuOption(id: 'wd3d', label: 'let it go for tonight', tag: 'rest'),
      ]),
    MenuCategory(id: 'wd4', emoji: '🌙', title: 'tomorrow starts now', sub: 'prep tonight = better tomorrow.',
      options: [
        MenuOption(id: 'wd4a', label: 'set ur 3 priorities', tag: 'content'),
        MenuOption(id: 'wd4b', label: "lay out tomorrow's stuff", tag: 'solo'),
        MenuOption(id: 'wd4c', label: 'phone on silent, alarm set', tag: 'rest'),
        MenuOption(id: 'wd4d', label: 'make something warm to wind down', tag: 'solo'),
      ]),
  ];

  static const _deepNightCore = <MenuCategory>[
    MenuCategory(id: 'dn1', emoji: '😴', title: 'sleep', sub: 'ur body needs it. no debate.',
      options: [
        MenuOption(id: 'dn1a', label: 'lights off, phone down', tag: 'rest'),
        MenuOption(id: 'dn1b', label: 'lie in the dark', tag: 'rest'),
        MenuOption(id: 'dn1c', label: 'boring podcast', tag: 'rest'),
        MenuOption(id: 'dn1d', label: 'eyes closed, done', tag: 'rest'),
      ]),
    MenuCategory(id: 'dn2', emoji: '🌬️', title: 'box breathing', sub: 'nervous system off.',
      options: [
        MenuOption(id: 'dn2a', label: '4 in, 4 hold, 4 out', tag: 'rest'),
        MenuOption(id: 'dn2b', label: 'slow the breathing down', tag: 'rest'),
        MenuOption(id: 'dn2c', label: 'eyes closed, count to 10', tag: 'rest'),
        MenuOption(id: 'dn2d', label: 'lie flat, breathe slow', tag: 'rest'),
      ]),
    MenuCategory(id: 'dn3', emoji: '📵', title: 'phone down', sub: "this is literally why u can't sleep.",
      options: [
        MenuOption(id: 'dn3a', label: 'face down, not in ur hand', tag: 'rest'),
        MenuOption(id: 'dn3b', label: 'across the room', tag: 'rest'),
        MenuOption(id: 'dn3c', label: 'grayscale mode at least', tag: 'rest'),
        MenuOption(id: 'dn3d', label: 'charge it away from ur bed', tag: 'rest'),
      ]),
    MenuCategory(id: 'dn4', emoji: '🎙️', title: 'boring podcast', sub: 'give ur brain something dull.',
      options: [
        MenuOption(id: 'dn4a', label: 'sleep with me podcast', tag: 'rest'),
        MenuOption(id: 'dn4b', label: 'history or science, no drama', tag: 'rest'),
        MenuOption(id: 'dn4c', label: 'audiobook ur not that into', tag: 'rest'),
        MenuOption(id: 'dn4d', label: 'rain sounds', tag: 'rest'),
      ]),
  ];

  static const _weekendCore = <MenuCategory>[
    MenuCategory(id: 'we1', emoji: '🗺️', title: 'explore something', sub: "the city's waiting.",
      options: [
        MenuOption(id: 'we1a', label: 'somewhere new on maps', tag: 'discover'),
        MenuOption(id: 'we1b', label: 'pop-up or market near u', tag: 'discover'),
        MenuOption(id: 'we1c', label: 'that cafe u saved', tag: 'discover'),
        MenuOption(id: 'we1d', label: 'just walk and see what u find', tag: 'solo'),
      ]),
    MenuCategory(id: 'we2', emoji: '☀️', title: 'get outside', sub: 'ur living in a cave. fix it.',
      options: [
        MenuOption(id: 'we2a', label: 'park or green space', tag: 'solo'),
        MenuOption(id: 'we2b', label: 'trail or walk', tag: 'solo'),
        MenuOption(id: 'we2c', label: 'sit outside somewhere', tag: 'rest'),
        MenuOption(id: 'we2d', label: 'morning run or bike', tag: 'solo'),
      ]),
    MenuCategory(id: 'we3', emoji: '👥', title: 'social plans', sub: "the weekend is for people.",
      options: [
        MenuOption(id: 'we3a', label: 'brunch with someone', tag: 'squad'),
        MenuOption(id: 'we3b', label: "text the ones u've been meaning to", tag: 'squad'),
        MenuOption(id: 'we3c', label: 'join something happening', tag: 'discover'),
        MenuOption(id: 'we3d', label: 'make weekend plans', tag: 'squad'),
      ]),
    MenuCategory(id: 'we4', emoji: '✨', title: 'treat urself', sub: "u actually deserve it.",
      options: [
        MenuOption(id: 'we4a', label: 'that thing u keep putting off', tag: 'solo'),
        MenuOption(id: 'we4b', label: 'fancy brunch or lunch', tag: 'discover'),
        MenuOption(id: 'we4c', label: 'buy the thing', tag: 'discover'),
        MenuOption(id: 'we4d', label: 'full spa or self-care afternoon', tag: 'rest'),
      ]),
  ];

  // ─── Public API ──────────────────────────────────────────────────────────────

  /// 4 core categories for this vibe (no NEW DROP).
  static List<MenuCategory> core(String vibe) =>
      vibe == 'fomo' ? _fomoCore : _jomoCore;

  /// Time-aware Layer 3 static fallback — matches what the Human Rhythm Engine
  /// would suggest for this moment without any AI call.
  static List<MenuCategory> coreForTime(String vibe, int hour, bool isWeekend) {
    if (hour >= 0 && hour < 5) return _deepNightCore;
    if (hour >= 5 && hour < 9) return _earlyMorningCore;
    if (hour >= 9 && hour < 18) return isWeekend ? _weekendCore : _workdayCore;
    if (hour >= 18 && hour < 22) return _primeTimeCore;
    return _windDownCore;
  }

  /// The rotating NEW DROP category for this vibe.
  static MenuCategory newDrop(String vibe) =>
      vibe == 'fomo' ? _fomoNewDrop : _jomoNewDrop;

  /// All categories including NEW DROP (core first, drop last).
  static List<MenuCategory> all(String vibe) => [
        ...core(vibe),
        newDrop(vibe),
      ];

  /// Option-specific squad WhatsApp draft. Returns null for options that
  /// intentionally have no pre-filled text (e.g. f2b "reach out to that one person").
  static String? squadMessageForOption(String optionId, String vibe) {
    return switch (optionId) {
      'f1a' => "who's free tonight, rooftop situation? don't overthink it.",
      'f1c' => "bar hop tonight, who's joining? first one to reply picks the first spot.",
      'f2a' => "ok what are we actually doing tonight. someone pick something rn.",
      'f2b' => null, // opens contact list only — no pre-filled message
      _     => squadMessage(vibe), // fallback for squad options in other time layers
    };
  }

  /// Random trom-voiced squad WhatsApp message for the given vibe.
  static String squadMessage(String vibe) {
    final fomoMsgs = [
      "oi what's everyone doing tonight 👀",
      "ok we're going out. someone pick the place. no excuses.",
      "we need to do something tonight fr. trom said so.",
      "who's free. we are NOT staying in.",
      "it's a going out night. last person to reply picks.",
    ];
    final jomoMsgs = [
      "rotting at home tonight. don't invite me anywhere.",
      "staying in. leave me alone respectfully 🛋️",
      "jomo night. trom is protecting my peace.",
      "not going anywhere tonight and i feel great about it.",
      "quiet night. come over or don't. no pressure.",
    ];
    final src = vibe == 'fomo' ? fomoMsgs : jomoMsgs;
    return (List<String>.from(src)..shuffle()).first;
  }
}
