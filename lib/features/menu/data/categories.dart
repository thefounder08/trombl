import 'package:flutter/foundation.dart';

/// Tag-to-action mapping — mirrors the prototype's TAG_ACTIONS engine.
/// Only these 5 tags trigger Level 2 action cards.
enum ActionType {
  discover,   // → BookMyShow deep link
  squad,      // → WhatsApp with trom-drafted message
  orderIn,    // → Zomato deep link
  rest,       // → DND internal screen
  content,    // → Instagram + caption
  comingSoon, // greyed out, not yet actionable
  none,       // no action
}

@immutable
class MenuOption {
  const MenuOption({
    required this.id,
    required this.label,
    required this.tag,
    this.action = ActionType.none,
    this.actionData,
  });
  final String id;
  final String label;
  final String tag;       // display tag (e.g. "squad", "discover")
  final ActionType action;
  final String? actionData; // extra data for the action (e.g. WhatsApp message)

  bool get isComingSoon => action == ActionType.comingSoon;
}

@immutable
class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.emoji,
    required this.title,
    required this.sub,
    required this.options,
    this.isNewDrop = false,
    this.newDropFlavor,
  });
  final String id;
  final String emoji;
  final String title;
  final String sub;
  final List<MenuOption> options;
  final bool isNewDrop;
  final String? newDropFlavor; // "just dropped · week of may 19"
}

abstract final class Categories {
  // ─── FOMO ───────────────────────────────────────────────────────────────────
  static const _fomo = <MenuCategory>[
    MenuCategory(
      id: 'f1', emoji: '🎉', title: 'go out tonight',
      sub: "something's happening. be there.",
      options: [
        MenuOption(id: 'f1a', label: 'rooftop or house party',        tag: 'squad',        action: ActionType.squad,       actionData: "oi what's everyone doing tonight 👀"),
        MenuOption(id: 'f1b', label: 'live music or gig',             tag: 'discover',     action: ActionType.discover),
        MenuOption(id: 'f1c', label: 'bar hop with the crew',         tag: 'coming soon',  action: ActionType.comingSoon),
        MenuOption(id: 'f1d', label: 'club / dance floor',            tag: 'coming soon',  action: ActionType.comingSoon),
      ],
    ),
    MenuCategory(
      id: 'f2', emoji: '👥', title: 'make plans w someone',
      sub: "u've been saying 'soon' for too long.",
      options: [
        MenuOption(id: 'f2a', label: 'text the group chat rn',             tag: 'squad',       action: ActionType.squad, actionData: "ok we're going out. someone pick the place. no excuses."),
        MenuOption(id: 'f2b', label: 'reach out to that one person',       tag: 'coming soon', action: ActionType.comingSoon),
        MenuOption(id: 'f2c', label: 'game night at someone\'s place',     tag: 'coming soon', action: ActionType.comingSoon),
        MenuOption(id: 'f2d', label: 'find something random and drag everyone', tag: 'coming soon', action: ActionType.comingSoon),
      ],
    ),
    MenuCategory(
      id: 'f3', emoji: '💸', title: 'treat urself',
      sub: "u deserve it and u know it.",
      options: [
        MenuOption(id: 'f3a', label: 'do something the future-you will remember', tag: 'coming soon', action: ActionType.comingSoon),
        MenuOption(id: 'f3b', label: 'fancy dinner, main character era',   tag: 'order in', action: ActionType.orderIn),
        MenuOption(id: 'f3c', label: 'book a concert or show',             tag: 'coming soon', action: ActionType.comingSoon),
        MenuOption(id: 'f3d', label: 'get ur hair or nails done',          tag: 'coming soon', action: ActionType.comingSoon),
      ],
    ),
    MenuCategory(
      id: 'f4', emoji: '📸', title: 'make or post something',
      sub: "the timeline needs u.",
      options: [
        MenuOption(id: 'f4a', label: 'instagram post or story',        tag: 'content',     action: ActionType.content),
        MenuOption(id: 'f4b', label: 'shoot a reel or vlog',           tag: 'coming soon', action: ActionType.comingSoon),
        MenuOption(id: 'f4c', label: 'drop a new spotify playlist',    tag: 'coming soon', action: ActionType.comingSoon),
        MenuOption(id: 'f4d', label: 'post ur honest opinion on something', tag: 'coming soon', action: ActionType.comingSoon),
      ],
    ),
  ];

  static const _fomoNewDrop = MenuCategory(
    id: 'fnew', emoji: '🏃', title: 'move ur body',
    sub: "physical fomo is real too. ur missing out on endorphins.",
    isNewDrop: true,
    newDropFlavor: 'just dropped',
    options: [
      MenuOption(id: 'fn1', label: 'gym session — actually go',             tag: 'discover',    action: ActionType.discover),
      MenuOption(id: 'fn2', label: 'group fitness class (pilates, boxing)',  tag: 'coming soon', action: ActionType.comingSoon),
      MenuOption(id: 'fn3', label: 'look up outdoor things happening today', tag: 'coming soon', action: ActionType.comingSoon),
      MenuOption(id: 'fn4', label: 'hike or trail',                          tag: 'coming soon', action: ActionType.comingSoon),
    ],
  );

  // ─── JOMO ───────────────────────────────────────────────────────────────────
  static const _jomo = <MenuCategory>[
    MenuCategory(
      id: 'j1', emoji: '🛌', title: 'fully rot today',
      sub: "no guilt. ur recharging. this is valid.",
      options: [
        MenuOption(id: 'j1a', label: 'binge netflix or youtube',       tag: 'coming soon', action: ActionType.comingSoon),
        MenuOption(id: 'j1b', label: 'rewatch ur comfort show',        tag: 'coming soon', action: ActionType.comingSoon),
        MenuOption(id: 'j1c', label: 'sleep in or nap aggressively',   tag: 'coming soon', action: ActionType.comingSoon),
        MenuOption(id: 'j1d', label: 'do absolutely nothing',          tag: 'rest',        action: ActionType.rest),
      ],
    ),
    MenuCategory(
      id: 'j2', emoji: '🍕', title: 'comfort food situation',
      sub: "let the food come to u. u earned it.",
      options: [
        MenuOption(id: 'j2a', label: 'ur usual from that one place',        tag: 'order in',    action: ActionType.orderIn),
        MenuOption(id: 'j2b', label: 'full snack spread, no actual meals',  tag: 'coming soon', action: ActionType.comingSoon),
        MenuOption(id: 'j2c', label: 'bake something (therapeutic fr)',     tag: 'coming soon', action: ActionType.comingSoon),
        MenuOption(id: 'j2d', label: 'make a fancy coffee and sit with it', tag: 'coming soon', action: ActionType.comingSoon),
      ],
    ),
    MenuCategory(
      id: 'j3', emoji: '✨', title: 'soft recharge',
      sub: "the quiet stuff that actually fills u up.",
      options: [
        MenuOption(id: 'j3a', label: 'do a full face mask and decompress',  tag: 'rest',        action: ActionType.rest),
        MenuOption(id: 'j3b', label: 'journal or full brain dump',          tag: 'coming soon', action: ActionType.comingSoon),
        MenuOption(id: 'j3c', label: 'long shower or bath — full ritual',   tag: 'coming soon', action: ActionType.comingSoon),
        MenuOption(id: 'j3d', label: 'clean and organise ur space',         tag: 'coming soon', action: ActionType.comingSoon),
      ],
    ),
    MenuCategory(
      id: 'j4', emoji: '💭', title: 'get in ur head',
      sub: "ur alone time is actually ur superpower.",
      options: [
        MenuOption(id: 'j4a', label: 'write down everything on ur mind',   tag: 'content',     action: ActionType.content),
        MenuOption(id: 'j4b', label: 'vision board ur next 6 months',       tag: 'coming soon', action: ActionType.comingSoon),
        MenuOption(id: 'j4c', label: 'reflect on the last month honestly',  tag: 'coming soon', action: ActionType.comingSoon),
        MenuOption(id: 'j4d', label: 'write a letter to ur future self',    tag: 'coming soon', action: ActionType.comingSoon),
      ],
    ),
  ];

  static const _jomoNewDrop = MenuCategory(
    id: 'jnew', emoji: '🎧', title: 'get lost in music',
    sub: "ur ears deserve a full uninterrupted day.",
    isNewDrop: true,
    newDropFlavor: 'just dropped',
    options: [
      MenuOption(id: 'jn1', label: 'full album, front to back',             tag: 'rest',        action: ActionType.rest),
      MenuOption(id: 'jn2', label: 'build a new playlist from scratch',     tag: 'coming soon', action: ActionType.comingSoon),
      MenuOption(id: 'jn3', label: 'find a completely new artist',          tag: 'coming soon', action: ActionType.comingSoon),
      MenuOption(id: 'jn4', label: 'podcast deep dive on something random', tag: 'coming soon', action: ActionType.comingSoon),
    ],
  );

  // ─── Public API ─────────────────────────────────────────────────────────────

  /// Core 4 categories for this vibe.
  static List<MenuCategory> forVibe(String vibe) =>
      vibe == 'fomo' ? _fomo : _jomo;

  /// The NEW DROP category for this vibe.
  static MenuCategory newDropFor(String vibe) =>
      vibe == 'fomo' ? _fomoNewDrop : _jomoNewDrop;

  /// WhatsApp squad messages — trom-written, used when action == squad.
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
    final msgs = vibe == 'fomo' ? fomoMsgs : jomoMsgs;
    msgs.shuffle();
    return msgs.first;
  }
}
