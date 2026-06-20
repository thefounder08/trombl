import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

import '../../../core/theme/trombl_theme.dart';
import 'menu_data.dart';
import 'menu_models.dart';

// ─── Result types ─────────────────────────────────────────────────────────────

sealed class ActionResult {
  const ActionResult();
  String get name;
}

/// Open a URL; launcher tries [url] first, then [fallbackUrl] if provided.
final class ExternalUrlAction extends ActionResult {
  const ExternalUrlAction(this.url, {this.fallbackUrl});
  final String url;
  final String? fallbackUrl;
  @override
  String get name => 'launched';
}

/// Primary URL with an optional secondary follow-up button.
/// Secondary button is shown after the primary URL has been launched.
final class DualUrlAction extends ActionResult {
  const DualUrlAction({
    required this.primaryUrl,
    this.primaryFallbackUrl,
    required this.secondaryLabel,
    required this.secondaryUrl,
  });
  final String primaryUrl;
  final String? primaryFallbackUrl;
  final String secondaryLabel;
  final String secondaryUrl;
  @override
  String get name => 'dual';
}

/// Multiple simultaneous URL buttons shown in place of "i'm on it →".
final class MultiButtonAction extends ActionResult {
  const MultiButtonAction(this.buttons);
  final List<({String label, String url})> buttons;
  @override
  String get name => 'multi_button';
}

/// Memory-aware: reads a saved preference, then deep-links; shows an inline
/// prompt to capture the preference the first time if not yet saved.
final class MemoryQueryAction extends ActionResult {
  const MemoryQueryAction({
    required this.memoryKey,
    required this.urlTemplate,
    required this.promptText,
  });
  final String memoryKey;
  final String urlTemplate; // '{value}' is replaced with the found/entered pref
  final String promptText;
  @override
  String get name => 'memory_query';
}

/// Navigate to an in-app GoRouter route.
final class InternalRouteAction extends ActionResult {
  const InternalRouteAction(this.route);
  final String route;
  @override
  String get name => 'internal';
}

/// Open the chat screen and pre-seed Trombl's opening message.
final class ChatSeedAction extends ActionResult {
  const ChatSeedAction(this.seedText);
  final String seedText;
  @override
  String get name => 'chat_seed';
}

/// Option deliberately not built yet — show a snackbar.
final class ComingSoonAction extends ActionResult {
  const ComingSoonAction();
  @override
  String get name => 'coming_soon';
}

/// No keyword matched — show a Trombl-voice snackbar with [message].
final class FailedAction extends ActionResult {
  const FailedAction(this.message);
  final String message;
  @override
  String get name => 'failed';
}

// ─── Tag enum ─────────────────────────────────────────────────────────────────

enum MenuTag {
  discover,
  squad,
  orderIn,
  rest,
  content,
  solo,
  comingSoon;

  static MenuTag fromString(String s) => switch (s) {
        'discover'    => MenuTag.discover,
        'squad'       => MenuTag.squad,
        'order in'    => MenuTag.orderIn,
        'rest'        => MenuTag.rest,
        'content'     => MenuTag.content,
        'solo'        => MenuTag.solo,
        'coming soon' => MenuTag.comingSoon,
        _             => MenuTag.comingSoon,
      };
}

// ─── UI metadata ──────────────────────────────────────────────────────────────

@immutable
class ActionDefinition {
  const ActionDefinition({
    required this.icon,
    required this.label,
    required this.description,
    required this.cta,
    required this.color,
  });
  final String icon;
  final String label;
  final String description;
  final String cta;
  final Color color;
}

// ─── Engine ───────────────────────────────────────────────────────────────────

abstract final class ActionEngine {
  static const _defs = <String, ActionDefinition>{
    'discover': ActionDefinition(
      icon: '🔍',
      label: 'find something near u',
      description: "trom's finding something worth going to",
      cta: 'trom, open it →',
      color: TromblColors.fomo,
    ),
    'squad': ActionDefinition(
      icon: '💬',
      label: 'text ur squad',
      description: "trom wrote the text. u just hit send.",
      cta: 'send it →',
      color: TromblColors.tagSquad,
    ),
    'order in': ActionDefinition(
      icon: '🍕',
      label: 'order comfort food',
      description: "trom's ordering ur comfort. sit down.",
      cta: 'trom, order →',
      color: TromblColors.tagOrderIn,
    ),
    'rest': ActionDefinition(
      icon: '🛌',
      label: 'protect ur peace',
      description: "trom's locking everything out. ur off the grid.",
      cta: 'lock it down →',
      color: TromblColors.jomo,
    ),
    'content': ActionDefinition(
      icon: '📸',
      label: 'post something',
      description: "trom wrote the caption. timeline needs u.",
      cta: 'post it →',
      color: TromblColors.tagContent,
    ),
    'solo': ActionDefinition(
      icon: '🎯',
      label: 'make it happen',
      description: "trom's pointing u in the right direction.",
      cta: 'trom, go →',
      color: TromblColors.fomo,
    ),
  };

  static ActionDefinition? definitionFor(String tag) => _defs[tag];
  static bool isActionable(String tag) => _defs.containsKey(tag);

  // ── Public resolver ────────────────────────────────────────────────────────

  static ActionResult resolve({
    required MenuOption option,
    required String vibe,
    String? tromMessage,
    String? city,
  }) {
    final tag = MenuTag.fromString(option.tag);
    return switch (tag) {
      MenuTag.discover   => _resolveDiscover(option.label, city),
      MenuTag.squad      => _resolveSquad(option.id, vibe, tromMessage),
      MenuTag.orderIn    => _resolveOrderIn(option.label, city),
      MenuTag.rest       => _resolveRest(option.label),
      MenuTag.content    => _resolveContent(option.label),
      MenuTag.solo       => _resolveSolo(option.label),
      MenuTag.comingSoon => const ComingSoonAction(),
    };
  }

  // ── Tag resolvers ──────────────────────────────────────────────────────────

  static ActionResult _resolveDiscover(String label, String? city) {
    final l = label.toLowerCase();

    // f1b — live music or gig → Insider.in (NOT BookMyShow)
    if (l.contains('live music') || l.contains('gig')) {
      return const ExternalUrlAction('https://insider.in/search?q=live+music');
    }

    // f1d — club / dance floor → WhatsApp draft + Maps secondary
    if (l.contains('club') || l.contains('dance floor')) {
      final wa = _whatsapp("club tonight, who’s actually coming?");
      return DualUrlAction(
        primaryUrl: wa.url,
        primaryFallbackUrl: wa.fallbackUrl,
        secondaryLabel: 'find one →',
        secondaryUrl: 'https://www.google.com/maps/search/nightclub+near+me',
      );
    }

    // f3b — book a concert or show → BMS generic events page
    if (l.contains('concert') || l.contains('book a')) {
      return const ExternalUrlAction('https://in.bookmyshow.com/explore/events');
    }

    // Activity / local-search options → Google Maps
    if (_any(l, [
      'gym', 'fitness', 'spot', 'class', 'cafe', 'coffee', 'walk',
      'around', 'close by', '5 min', 'maps', 'market', 'pop-up', 'nearby',
      'trail', 'hike', 'outdoor', 'bike', 'dinner', 'brunch', 'lunch',
      'restaurant', 'hair', 'nails', 'salon', 'somewhere new', 'find a',
      'fancy', 'fine dining',
    ])) {
      return ExternalUrlAction(
        'https://www.google.com/maps/search/${Uri.encodeComponent(_mapsQueryForDiscover(l))}',
      );
    }

    // Ticketed events → BookMyShow with Google Maps fallback
    final eventQuery = _bmsQuery(l);
    final slug = city != null ? _slug(city) : null;
    final bmsUrl = slug != null
        ? 'https://in.bookmyshow.com/explore/events-$slug?q=${Uri.encodeComponent(eventQuery)}'
        : 'https://in.bookmyshow.com/explore/events?q=${Uri.encodeComponent(eventQuery)}';
    return ExternalUrlAction(
      bmsUrl,
      fallbackUrl:
          'https://www.google.com/maps/search/${Uri.encodeComponent("events near me")}',
    );
  }

  static ActionResult _resolveSquad(
      String optionId, String vibe, String? tromMessage) {
    // f2b — reach out to that one person: no pre-filled text, just open contacts
    if (optionId == 'f2b') {
      final wa = _whatsapp(null);
      return ExternalUrlAction(wa.url, fallbackUrl: wa.fallbackUrl);
    }

    // f1c — bar hop with the crew: specific draft + secondary Maps button
    if (optionId == 'f1c') {
      final msg = tromMessage ??
          "bar hop tonight, who's joining? first one to reply picks the first spot.";
      final wa = _whatsapp(msg);
      return DualUrlAction(
        primaryUrl: wa.url,
        primaryFallbackUrl: wa.fallbackUrl,
        secondaryLabel: 'find a bar →',
        secondaryUrl: 'https://www.google.com/maps/search/bars+near+me',
      );
    }

    // All other squad options — WhatsApp with the drafted message
    final msg = tromMessage ?? TromblMenu.squadMessage(vibe);
    final wa = _whatsapp(msg);
    return ExternalUrlAction(wa.url, fallbackUrl: wa.fallbackUrl);
  }

  /// WhatsApp launch URLs. [text] null → bare contact picker, no draft.
  ///
  /// `whatsapp://send` is tried first — it's the app's native scheme and
  /// resolves directly on Android/iOS when WhatsApp is installed.
  /// `https://wa.me/` is the fallback: it depends on Android App Link
  /// verification to route into the app, which isn't always reliable, but it
  /// degrades correctly to WhatsApp Web on browsers/desktop where the native
  /// scheme doesn't exist (e.g. the web build).
  static ({String url, String fallbackUrl}) _whatsapp(String? text) {
    final q = text != null ? '?text=${Uri.encodeComponent(text)}' : '';
    return (url: 'whatsapp://send$q', fallbackUrl: 'https://wa.me/$q');
  }

  static ActionResult _resolveOrderIn(String label, String? city) {
    final l = label.toLowerCase();

    // j2a — ur usual from that one place: memory-aware Zomato
    if (l.contains('usual')) {
      return const MemoryQueryAction(
        memoryKey: 'usual_place',
        urlTemplate: 'https://www.zomato.com/search?q={value}',
        promptText: "what's ur go-to place?",
      );
    }

    // j2b — full snack spread: Zomato snacks search
    if (l.contains('snack')) {
      return const ExternalUrlAction(
        'https://www.zomato.com/search?q=snacks+munchies',
      );
    }

    // Generic fallback: Zomato cuisine search
    final cuisine = _inferCuisine(l);
    final enc = Uri.encodeComponent(cuisine);
    final zomatoDeep = 'zomato://search?query=$enc';
    final String webFallback;
    if (city != null) {
      webFallback = 'https://www.zomato.com/${_slug(city)}/delivery?q=$enc';
    } else {
      webFallback =
          'https://www.google.com/maps/search/${Uri.encodeComponent("$cuisine delivery")}';
    }
    return ExternalUrlAction(zomatoDeep, fallbackUrl: webFallback);
  }

  static ActionResult _resolveRest(String label) {
    final l = label.toLowerCase();

    // j2d (now rest) — make a fancy coffee: three YouTube recipe options
    if (l.contains('coffee')) {
      return const MultiButtonAction([
        (label: '☕ dalgona whip →', url: 'https://www.youtube.com/results?search_query=dalgona+coffee+recipe'),
        (label: '🫗 pour over →',    url: 'https://www.youtube.com/results?search_query=pour+over+coffee+at+home'),
        (label: '🧊 iced latte →',   url: 'https://www.youtube.com/results?search_query=iced+latte+at+home+easy'),
      ]);
    }

    // j2c (now rest) — bake something: YouTube baking recipe
    if (l.contains('bake')) {
      return const ExternalUrlAction(
        'https://www.youtube.com/results?search_query=easy+baking+recipe+beginner',
      );
    }

    // Legacy rest options that carry streaming/music labels
    if (_any(l, ['endless', 'videos'])) {
      return const ExternalUrlAction('https://www.youtube.com/');
    }
    if (_any(l, ['watch', 'binge'])) {
      return const ExternalUrlAction(
        'https://www.netflix.com/',
        fallbackUrl: 'https://www.youtube.com/',
      );
    }
    if (_any(l, ['album', 'spotify', 'music', 'playlist'])) {
      return const ExternalUrlAction(
        'spotify://',
        fallbackUrl: 'https://open.spotify.com/',
      );
    }

    return const InternalRouteAction('/dnd');
  }

  static ActionResult _resolveContent(String label) {
    final l = label.toLowerCase();

    // j3b, j4a — journal / brain dump / write down → in-app journal screen
    if (l.contains('brain dump') || l.contains('write down')) {
      return const InternalRouteAction('/journal');
    }

    // Spotify / playlist / music
    if (_any(l, ['spotify', 'playlist', 'music', 'song', 'album'])) {
      return const ExternalUrlAction(
        'spotify://',
        fallbackUrl: 'https://open.spotify.com/',
      );
    }

    // Remaining journal / reflect / write options → chat seed
    if (_any(l, [
      'journal', 'write', 'reflect', 'vent',
      'priorities', 'letter', 'vision board', 'honest', 'opinion',
    ])) {
      return ChatSeedAction(_contentSeed(l));
    }

    // Reel / vlog
    if (l.contains('reel') || l.contains('vlog')) {
      return const ExternalUrlAction(
        'instagram://reels',
        fallbackUrl: 'https://www.instagram.com/reels/',
      );
    }

    // Post / story / photo
    if (_any(l, ['post', 'story', 'photo'])) {
      return const ExternalUrlAction(
        'instagram://camera',
        fallbackUrl: 'https://www.instagram.com/',
      );
    }

    return const ExternalUrlAction(
      'instagram://',
      fallbackUrl: 'https://www.instagram.com/',
    );
  }

  static ActionResult _resolveSolo(String label) {
    final l = label.toLowerCase();

    if (_any(l, ['sleep', 'bed', 'lights out', 'log off', 'phone down'])) {
      return const InternalRouteAction('/dnd');
    }

    if (_any(l, [
      'wind down', 'unplug', 'slow morning', 'journal', 'reflect',
      'brain dump', 'vent',
    ])) {
      return ChatSeedAction(_journalSeed(l));
    }

    if (_any(l, [
      'walk', 'run', 'jog', 'stretch', 'steps', 'trail', 'outside',
      'bench', 'park', 'bike', 'breathing', 'sunlight', 'block',
      'leave', 'desk', 'move',
    ])) {
      return const ExternalUrlAction(
        'https://www.google.com/maps/search/park+near+me',
      );
    }

    if (_any(l, ['gym', 'workout', 'fitness'])) {
      return const ExternalUrlAction(
        'https://www.google.com/maps/search/gym+near+me',
      );
    }

    if (_any(l, [
      'music', 'playlist', 'spotify', 'song', 'lofi', 'podcast',
      'album', 'artist', 'listen',
    ])) {
      return const ExternalUrlAction(
        'spotify://',
        fallbackUrl: 'https://open.spotify.com/',
      );
    }

    if (_any(l, ['series', 'episode', 'rewatch', 'comfort show', 'netflix'])) {
      final q = l.contains('comfort') ? 'comfort show' : 'series';
      return ExternalUrlAction(
        'https://www.netflix.com/search?q=${Uri.encodeComponent(q)}',
      );
    }

    if (l.contains('binge')) {
      return const ChatSeedAction(
        "okay what are we feeling — comfort rewatch or something new?",
      );
    }

    if (_any(l, ['movie', 'watch', 'film'])) {
      return const ExternalUrlAction('https://www.youtube.com/');
    }

    if (_any(l, ['read', 'book', 'article'])) {
      return const ExternalUrlAction('https://www.goodreads.com/');
    }

    if (_any(l, ['cook', 'recipe', 'bake', 'make', 'meal', 'warm'])) {
      return ExternalUrlAction(
        'https://www.youtube.com/results?search_query=${Uri.encodeComponent("easy recipes")}',
      );
    }

    if (_any(l, ['write', 'reflect', 'breathe', 'reset'])) {
      return ChatSeedAction(_journalSeed(l));
    }

    if (_any(l, [
      'timer', 'task', 'inbox', 'blocker', 'tomorrow', 'priorities',
      'small', 'putting off', 'tonight', 'one thing', 'stuff',
    ])) {
      return ChatSeedAction(_focusSeed(l));
    }

    debugPrint('[ActionEngine] solo: no keyword matched for "$label"');
    return const FailedAction(
      "hm, that one's not wired up yet. tell me what you were going for.",
    );
  }

  // ── Seed text helpers ──────────────────────────────────────────────────────

  static String _journalSeed(String l) {
    if (_any(l, ['reflect', 'today'])) {
      return "ok let's get it all out. what happened today that's actually on ur mind?";
    }
    if (_any(l, ['tomorrow', 'priorities', 'stuff'])) {
      return "ok let's plan. what do u actually need to sort before tomorrow?";
    }
    if (_any(l, ['write', 'brain dump'])) {
      return "ok brain dump mode. what's in ur head right now? all of it.";
    }
    if (_any(l, ['wind down', 'breathe', 'unplug', 'slow morning'])) {
      return "ok winding down. what do u need to let go of tonight?";
    }
    return "ok let's get it out. what's actually on ur mind?";
  }

  static String _focusSeed(String l) {
    if (_any(l, ['timer', 'task', 'inbox'])) {
      return "ok focus mode. what are we working on? just say it.";
    }
    if (l.contains('blocker')) {
      return "what's the actual blocker? let's name it and work through it.";
    }
    if (_any(l, ['tomorrow', 'priorities', 'stuff'])) {
      return "ok let's plan tomorrow. what are the 3 things that actually matter?";
    }
    if (_any(l, ['small', 'one thing', 'putting off'])) {
      return "ok what's the thing? say it. ur going to do it.";
    }
    if (l.contains('tonight')) {
      return "so what does tonight-u actually want to do? let's figure it out.";
    }
    return "ok what are we working on? tell trom.";
  }

  static String _contentSeed(String l) {
    if (_any(l, ['brain dump', 'write', 'mind'])) {
      return "ok brain dump mode. what's in ur head? all of it.";
    }
    if (_any(l, ['reflect', 'journal'])) {
      return "ok let's process. what's been going on?";
    }
    if (_any(l, ['priorities', 'top 3'])) {
      return "ok what are ur actual 3 priorities? let's get real.";
    }
    if (_any(l, ['honest', 'opinion'])) {
      return "ok what's the take? what's actually on ur mind?";
    }
    if (_any(l, ['letter', 'future'])) {
      return "ok. what do u want future-u to know? start anywhere.";
    }
    if (_any(l, ['vision', 'board'])) {
      return "ok vision board mode. what does the next 6 months look like if everything goes right?";
    }
    return "ok let's get it out. what are u thinking?";
  }

  // ── Discover helpers ───────────────────────────────────────────────────────

  static String _mapsQueryForDiscover(String l) {
    if (l.contains('fancy') || l.contains('fine dining') ||
        l.contains('main character')) {
      return 'fine dining near me';
    }
    if (l.contains('gym') || l.contains('fitness') || l.contains('class')) {
      return 'gym near me';
    }
    if (l.contains('cafe') || l.contains('coffee')) return 'cafe near me';
    if (l.contains('hike') || l.contains('trail') || l.contains('outdoor')) {
      return 'hiking trails near me';
    }
    if (l.contains('hair') || l.contains('nails') || l.contains('salon')) {
      return 'nail salon near me';
    }
    if (l.contains('dinner') || l.contains('brunch') || l.contains('lunch') ||
        l.contains('restaurant')) {
      return 'restaurants near me';
    }
    if (l.contains('market') || l.contains('pop-up')) return 'markets near me';
    return 'things to do near me';
  }

  static String _bmsQuery(String l) {
    if (_any(l, ['music', 'gig', 'concert', 'live'])) {
      return 'live music tonight';
    }
    if (l.contains('club') || l.contains('dance')) return 'nightclub tonight';
    if (l.contains('comedy')) return 'comedy show tonight';
    if (l.contains('show')) return 'show tonight';
    return 'events tonight near me';
  }

  // ── Order-in helpers ───────────────────────────────────────────────────────

  static String _inferCuisine(String l) {
    if (l.contains('pizza'))                          return 'pizza';
    if (l.contains('biryani'))                        return 'biryani';
    if (l.contains('burger'))                         return 'burgers';
    if (l.contains('chinese'))                        return 'chinese';
    if (l.contains('momos'))                          return 'momos';
    if (l.contains('dessert') || l.contains('sweet')) return 'dessert';
    if (l.contains('bake') || l.contains('bakery'))  return 'dessert';
    if (l.contains('ice cream'))                      return 'ice cream';
    if (l.contains('chai'))                           return 'chai';
    if (l.contains('coffee'))                         return 'coffee';
    if (l.contains('south indian') || l.contains('dosa')) {
      return 'south indian';
    }
    if (l.contains('shawarma') || l.contains('roll')) return 'rolls';
    if (l.contains('thali'))                          return 'thali';
    if (l.contains('snack'))                          return 'snacks';
    if (l.contains('late night'))                     return 'late night food';
    if (l.contains('breakfast'))                      return 'breakfast';
    if (l.contains('dinner'))                         return 'dinner';
    if (l.contains('fancy'))                          return 'fine dining';
    if (l.contains('comfort'))                        return 'comfort food';
    if (l.contains('meal'))                           return 'comfort food';
    return 'comfort food';
  }

  // ── Shared utilities ───────────────────────────────────────────────────────

  static bool _any(String label, List<String> keywords) =>
      keywords.any((k) => label.contains(k));

  static String _slug(String city) =>
      city.toLowerCase().replaceAll(' ', '-');
}
