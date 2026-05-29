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
        MenuOption(id: 'f1c', label: 'bar hop with the crew',               tag: 'coming soon'),
        MenuOption(id: 'f1d', label: 'club / dance floor',                  tag: 'coming soon'),
      ],
    ),
    MenuCategory(
      id: 'f2', emoji: '👥', title: 'make plans w someone',
      sub: "u've been saying 'soon' for too long.",
      options: [
        MenuOption(id: 'f2a', label: 'text the group chat rn',                   tag: 'squad'),
        MenuOption(id: 'f2b', label: 'reach out to that one person',             tag: 'coming soon'),
        MenuOption(id: 'f2c', label: "game night at someone's place",            tag: 'coming soon'),
        MenuOption(id: 'f2d', label: 'find something random and drag everyone',  tag: 'coming soon'),
      ],
    ),
    MenuCategory(
      id: 'f3', emoji: '💸', title: 'treat urself',
      sub: "u deserve it and u know it.",
      options: [
        MenuOption(id: 'f3a', label: 'do something the future-you will remember', tag: 'coming soon'),
        MenuOption(id: 'f3b', label: 'fancy dinner, main character era',          tag: 'order in'),
        MenuOption(id: 'f3c', label: 'book a concert or show',                    tag: 'discover'),
        MenuOption(id: 'f3d', label: 'get ur hair or nails done',                 tag: 'coming soon'),
      ],
    ),
    MenuCategory(
      id: 'f4', emoji: '📸', title: 'make or post something',
      sub: "the timeline needs u.",
      options: [
        MenuOption(id: 'f4a', label: 'instagram post or story',           tag: 'content'),
        MenuOption(id: 'f4b', label: 'shoot a reel or vlog',              tag: 'coming soon'),
        MenuOption(id: 'f4c', label: 'drop a new spotify playlist',       tag: 'coming soon'),
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
        MenuOption(id: 'j1a', label: 'binge netflix or youtube',         tag: 'coming soon'),
        MenuOption(id: 'j1b', label: 'rewatch ur comfort show',          tag: 'coming soon'),
        MenuOption(id: 'j1c', label: 'sleep in or nap aggressively',     tag: 'coming soon'),
        MenuOption(id: 'j1d', label: 'do absolutely nothing',            tag: 'rest'),
      ],
    ),
    MenuCategory(
      id: 'j2', emoji: '🍕', title: 'comfort food situation',
      sub: "let the food come to u. u earned it.",
      options: [
        MenuOption(id: 'j2a', label: 'ur usual from that one place',         tag: 'order in'),
        MenuOption(id: 'j2b', label: 'full snack spread, no actual meals',   tag: 'coming soon'),
        MenuOption(id: 'j2c', label: 'bake something (therapeutic fr)',      tag: 'coming soon'),
        MenuOption(id: 'j2d', label: 'make a fancy coffee and sit with it',  tag: 'coming soon'),
      ],
    ),
    MenuCategory(
      id: 'j3', emoji: '✨', title: 'soft recharge',
      sub: "the quiet stuff that actually fills u up.",
      options: [
        MenuOption(id: 'j3a', label: 'do a full face mask and decompress',   tag: 'rest'),
        MenuOption(id: 'j3b', label: 'journal or full brain dump',           tag: 'coming soon'),
        MenuOption(id: 'j3c', label: 'long shower or bath — full ritual',    tag: 'coming soon'),
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

  // ─── Public API ──────────────────────────────────────────────────────────────

  /// 4 core categories for this vibe (no NEW DROP).
  static List<MenuCategory> core(String vibe) =>
      vibe == 'fomo' ? _fomoCore : _jomoCore;

  /// The rotating NEW DROP category for this vibe.
  static MenuCategory newDrop(String vibe) =>
      vibe == 'fomo' ? _fomoNewDrop : _jomoNewDrop;

  /// All categories including NEW DROP (core first, drop last).
  static List<MenuCategory> all(String vibe) => [
        ...core(vibe),
        newDrop(vibe),
      ];

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
