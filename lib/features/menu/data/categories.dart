import 'package:flutter/foundation.dart';

enum ActionType { zomato, bookmyshow, whatsapp, dnd, none }

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
  final String tag;
  final ActionType action;
  final String? actionData;
}

@immutable
class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.emoji,
    required this.label,
    required this.options,
  });
  final String id;
  final String emoji;
  final String label;
  final List<MenuOption> options;
}

abstract final class Categories {
  static const _fomo = <MenuCategory>[
    MenuCategory(
      id: 'eat-out', emoji: '🍜', label: 'eat out',
      options: [
        MenuOption(id: 'eat-nearby', label: 'find something nearby', tag: 'food', action: ActionType.zomato),
        MenuOption(id: 'eat-cafe', label: 'grab a coffee', tag: 'cafe', action: ActionType.zomato),
        MenuOption(id: 'eat-new', label: 'try something new', tag: 'explore-food', action: ActionType.zomato),
        MenuOption(id: 'eat-late', label: 'late night bites', tag: 'late-food', action: ActionType.zomato),
      ],
    ),
    MenuCategory(
      id: 'watch-out', emoji: '🎬', label: 'watch',
      options: [
        MenuOption(id: 'watch-cinema', label: 'cinema tonight', tag: 'cinema', action: ActionType.bookmyshow),
        MenuOption(id: 'watch-event', label: 'live event or show', tag: 'event', action: ActionType.bookmyshow),
        MenuOption(id: 'watch-comedy', label: 'stand-up or comedy', tag: 'comedy', action: ActionType.bookmyshow),
      ],
    ),
    MenuCategory(
      id: 'plans', emoji: '🤙', label: 'make plans',
      options: [
        MenuOption(id: 'plans-crew', label: 'rally the crew', tag: 'social', action: ActionType.whatsapp, actionData: "yo who's free rn? trombl said go out 🔥"),
        MenuOption(id: 'plans-one', label: 'call one person', tag: 'one-on-one', action: ActionType.whatsapp, actionData: "u free? wanna do something random 👀"),
        MenuOption(id: 'plans-date', label: 'date night', tag: 'romantic', action: ActionType.whatsapp, actionData: "u and me tonight? trombl's orders 🔥"),
      ],
    ),
    MenuCategory(
      id: 'move', emoji: '🏃', label: 'move',
      options: [
        MenuOption(id: 'move-walk', label: 'random walk', tag: 'walk'),
        MenuOption(id: 'move-gym', label: 'hit the gym', tag: 'gym'),
        MenuOption(id: 'move-run', label: 'run it out', tag: 'run'),
        MenuOption(id: 'move-sport', label: 'play something', tag: 'sport'),
      ],
    ),
    MenuCategory(
      id: 'shop', emoji: '🛍', label: 'shop',
      options: [
        MenuOption(id: 'shop-thrift', label: 'thrift hunting', tag: 'thrift'),
        MenuOption(id: 'shop-mall', label: 'mall run', tag: 'mall'),
        MenuOption(id: 'shop-online', label: 'doomscroll + buy', tag: 'online'),
      ],
    ),
    MenuCategory(
      id: 'explore', emoji: '🌆', label: 'explore',
      options: [
        MenuOption(id: 'explore-spot', label: 'find a new spot', tag: 'explore'),
        MenuOption(id: 'explore-rooftop', label: 'rooftop or scenic view', tag: 'scenic'),
        MenuOption(id: 'explore-market', label: 'street market or pop-up', tag: 'market'),
      ],
    ),
  ];

  static const _jomo = <MenuCategory>[
    MenuCategory(
      id: 'order-in', emoji: '🛵', label: 'order in',
      options: [
        MenuOption(id: 'order-comfort', label: 'comfort food', tag: 'comfort', action: ActionType.zomato),
        MenuOption(id: 'order-healthy', label: 'something healthy', tag: 'healthy', action: ActionType.zomato),
        MenuOption(id: 'order-guilty', label: 'guilty pleasure', tag: 'indulge', action: ActionType.zomato),
      ],
    ),
    MenuCategory(
      id: 'watch-home', emoji: '📺', label: 'watch',
      options: [
        MenuOption(id: 'watch-binge', label: 'binge something', tag: 'binge'),
        MenuOption(id: 'watch-rewatch', label: 'rewatch a fav', tag: 'comfort-watch'),
        MenuOption(id: 'watch-doc', label: 'learn something random', tag: 'documentary'),
      ],
    ),
    MenuCategory(
      id: 'read', emoji: '📖', label: 'read',
      options: [
        MenuOption(id: 'read-fiction', label: 'get lost in fiction', tag: 'fiction'),
        MenuOption(id: 'read-rabbit', label: 'internet rabbit hole', tag: 'articles'),
        MenuOption(id: 'read-manga', label: 'manga or webtoon', tag: 'manga'),
      ],
    ),
    MenuCategory(
      id: 'rest', emoji: '😴', label: 'rest',
      options: [
        MenuOption(id: 'rest-nap', label: 'guilt-free nap', tag: 'nap', action: ActionType.dnd),
        MenuOption(id: 'rest-nothing', label: 'do absolutely nothing', tag: 'nothing', action: ActionType.dnd),
        MenuOption(id: 'rest-meditate', label: 'breathe and meditate', tag: 'mindful'),
      ],
    ),
    MenuCategory(
      id: 'listen', emoji: '🎵', label: 'listen',
      options: [
        MenuOption(id: 'listen-playlist', label: 'find a playlist', tag: 'music'),
        MenuOption(id: 'listen-podcast', label: 'podcast rabbit hole', tag: 'podcast'),
        MenuOption(id: 'listen-lofi', label: 'ambient or lofi', tag: 'ambient'),
      ],
    ),
    MenuCategory(
      id: 'create', emoji: '✏️', label: 'create',
      options: [
        MenuOption(id: 'create-draw', label: 'doodle or sketch', tag: 'art'),
        MenuOption(id: 'create-write', label: 'journal or write', tag: 'writing'),
        MenuOption(id: 'create-cook', label: 'cook something', tag: 'cooking'),
      ],
    ),
  ];

  static List<MenuCategory> forVibe(String vibe) =>
      vibe == 'fomo' ? _fomo : _jomo;
}
