import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

import '../../../core/theme/trombl_theme.dart';
import 'menu_data.dart';
import 'menu_models.dart';

// ─── Result type ─────────────────────────────────────────────────────────────

sealed class ActionResult {
  const ActionResult();

  /// Stable string sent to analytics — mirrors old enum `.name` values where
  /// backward-compatible, new names elsewhere.
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

/// All tags that appear in [MenuOption.tag]. Exhaustive — add here when a new
/// tag is introduced so the compiler flags unhandled cases immediately.
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
        _             => MenuTag.comingSoon, // safe default — shows snackbar
      };
}

// ─── UI metadata ──────────────────────────────────────────────────────────────

/// Metadata that describes how to present an actionable tag in the UI.
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

/// Pure resolver: option → ActionResult. No url_launcher, no BuildContext,
/// no GoRouter. All platform calls live in ActionLauncher (presentation layer).
///
/// Tag → destination summary
/// ───────────────────────────────────────────────────────────────────────────
/// discover   → Maps (activity keywords) or BookMyShow+Maps-fallback (events)
/// squad      → WhatsApp wa.me with trom-drafted message
/// order in   → Zomato deep link, web fallback (city-scoped or Maps delivery)
/// content    → Spotify | ChatSeed | Instagram reels/camera/home
/// rest       → InternalRouteAction('/dnd')
/// solo       → keyword-routed: Maps | Gym | Spotify | Netflix | ChatSeed | …
/// coming soon→ ComingSoonAction
abstract final class ActionEngine {
  // ── UI metadata map ────────────────────────────────────────────────────────

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

  /// The [ActionDefinition] for [tag], or null if not actionable.
  static ActionDefinition? definitionFor(String tag) => _defs[tag];

  /// True when [tag] has a real action wired up.
  static bool isActionable(String tag) => _defs.containsKey(tag);

  // ── Public resolver ────────────────────────────────────────────────────────

  /// Resolve [option] to an [ActionResult]. Synchronous and pure.
  ///
  /// [city] is the user's city name (e.g. "Mumbai") used to build city-scoped
  /// URLs for BookMyShow and Zomato; pass null when unknown.
  static ActionResult resolve({
    required MenuOption option,
    required String vibe,
    String? tromMessage,
    String? city,
  }) {
    final tag = MenuTag.fromString(option.tag);
    return switch (tag) {
      MenuTag.discover   => _resolveDiscover(option.label, city),
      MenuTag.squad      => _resolveSquad(vibe, tromMessage),
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

    // Activity / local-search options → Google Maps (no ticket needed).
    if (_any(l, [
      'gym', 'fitness', 'spot', 'class', 'cafe', 'coffee', 'walk',
      'around', 'close by', '5 min', 'maps', 'market', 'pop-up', 'nearby',
      'trail', 'hike', 'outdoor', 'bike', 'dinner', 'brunch', 'lunch',
      'restaurant', 'hair', 'nails', 'salon', 'somewhere new', 'find a',
    ])) {
      return ExternalUrlAction(
        'https://www.google.com/maps/search/${Uri.encodeComponent(_mapsQueryForDiscover(l))}',
      );
    }

    // Ticketed events → BookMyShow with Google Maps fallback.
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

  static ActionResult _resolveSquad(String vibe, String? tromMessage) {
    final msg = tromMessage ?? TromblMenu.squadMessage(vibe);
    return ExternalUrlAction(
      'https://wa.me/?text=${Uri.encodeComponent(msg)}',
    );
  }

  static ActionResult _resolveOrderIn(String label, String? city) {
    final cuisine = _inferCuisine(label.toLowerCase());
    final enc = Uri.encodeComponent(cuisine);

    // Primary: Zomato deep link (installed app knows user location).
    final zomatoDeep = 'zomato://search?query=$enc';

    // Fallback: city-scoped Zomato web, or Google Maps delivery search.
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
    // A few static JOMO options are labelled as streaming/music content but
    // carry the 'rest' tag. Route them to the right platform; everything else
    // goes to the DnD screen.
    if (l.contains('rewatch') || l.contains('comfort show')) {
      return ExternalUrlAction(
        'https://www.netflix.com/search?q=${Uri.encodeComponent('comfort show')}',
      );
    }
    if (_any(l, ['netflix', 'binge', 'youtube'])) {
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

    // Spotify / playlist / music.
    if (_any(l, ['spotify', 'playlist', 'music', 'song', 'album'])) {
      return const ExternalUrlAction(
        'spotify://',
        fallbackUrl: 'https://open.spotify.com/',
      );
    }

    // Journal / brain dump / write → stay in chat.
    if (_any(l, [
      'brain dump', 'journal', 'write', 'reflect', 'vent',
      'priorities', 'letter', 'vision board', 'honest', 'opinion',
    ])) {
      return ChatSeedAction(_contentSeed(l));
    }

    // Reel / vlog.
    if (l.contains('reel') || l.contains('vlog')) {
      return const ExternalUrlAction(
        'instagram://reels',
        fallbackUrl: 'https://www.instagram.com/reels/',
      );
    }

    // Post / story / photo.
    if (_any(l, ['post', 'story', 'photo'])) {
      return const ExternalUrlAction(
        'instagram://camera',
        fallbackUrl: 'https://www.instagram.com/',
      );
    }

    // Default → Instagram home.
    return const ExternalUrlAction(
      'instagram://',
      fallbackUrl: 'https://www.instagram.com/',
    );
  }

  /// Keyword-routed handler for the `solo` tag.
  ///
  /// Label → destination table (all time-aware solo options verified):
  ///
  /// 'sunlight first, phone second'        → Maps park (sunlight → outside)
  /// '5 minutes outside'                   → Maps park
  /// 'make something warm'                 → YouTube recipe (make/warm)
  /// 'proper meal, no excuses'             → YouTube recipe (meal)
  /// 'quick walk outside'                  → Maps park
  /// 'whatever gets u breathing'           → Maps park (breathing = movement)
  /// 'one small thing done'                → ChatSeed focus
  /// 'timer on, everything off'            → ChatSeed focus
  /// 'one task, start to finish'           → ChatSeed focus
  /// 'inbox zero, just one folder'         → ChatSeed focus
  /// 'away from the desk — non-negotiable' → Maps park (desk = step away)
  /// 'walk around the block'               → Maps park
  /// 'find a bench'                        → Maps park (bench = outside)
  /// 'clear the blocker'                   → ChatSeed focus
  /// 'just leave the house'                → Maps park (leave = go out)
  /// 'evening run or walk'                 → Maps park
  /// 'whatever tonight version of u wants' → ChatSeed (tonight = vague evening)
  /// 'reflect on today honestly'           → ChatSeed journal
  /// 'one thing for tomorrow'              → ChatSeed focus
  /// "lay out tomorrow's stuff"            → ChatSeed focus
  /// 'make something warm to wind down'    → ChatSeed (wind down wins)
  /// 'just walk and see what u find'       → Maps park
  /// 'park or green space'                 → Maps park
  /// 'trail or walk'                       → Maps park
  /// 'morning run or bike'                 → Maps park
  /// 'that thing u keep putting off'       → ChatSeed focus
  static ActionResult _resolveSolo(String label) {
    final l = label.toLowerCase();

    // ── 1. Sleep / phone-down → /dnd ──────────────────────────────────────
    if (_any(l, ['sleep', 'bed', 'lights out', 'log off', 'phone down'])) {
      return const InternalRouteAction('/dnd');
    }

    // ── 2. Wind-down / journal → ChatSeed ─────────────────────────────────
    // Checked BEFORE cook/make so "make something warm to wind down" → seed,
    // not YouTube. Also handles explicit breathe/reset/slow morning.
    if (_any(l, [
      'wind down', 'unplug', 'slow morning', 'journal', 'reflect',
      'brain dump', 'vent',
    ])) {
      return ChatSeedAction(_journalSeed(l));
    }

    // ── 3. Movement → Maps park ────────────────────────────────────────────
    // 'breathing' here means physical-activity context (not the explicit
    // keyword 'breathe' which is in bucket 2 for wind-down journaling).
    if (_any(l, [
      'walk', 'run', 'jog', 'stretch', 'steps', 'trail', 'outside',
      'bench', 'park', 'bike', 'breathing', 'sunlight', 'block',
      'leave', 'desk', 'move',
    ])) {
      return const ExternalUrlAction(
        'https://www.google.com/maps/search/park+near+me',
      );
    }

    // ── 4. Gym → Maps gym ──────────────────────────────────────────────────
    if (_any(l, ['gym', 'workout', 'fitness'])) {
      return const ExternalUrlAction(
        'https://www.google.com/maps/search/gym+near+me',
      );
    }

    // ── 5. Music → Spotify ─────────────────────────────────────────────────
    if (_any(l, [
      'music', 'playlist', 'spotify', 'song', 'lofi', 'podcast',
      'album', 'artist', 'listen',
    ])) {
      return const ExternalUrlAction(
        'spotify://',
        fallbackUrl: 'https://open.spotify.com/',
      );
    }

    // ── 6. Netflix — series/rewatch (checked BEFORE generic 'watch') ───────
    if (_any(l, ['series', 'episode', 'rewatch', 'comfort show', 'netflix'])) {
      final q = l.contains('comfort') ? 'comfort show' : 'series';
      return ExternalUrlAction(
        'https://www.netflix.com/search?q=${Uri.encodeComponent(q)}',
      );
    }

    // ── 7. Binge → ChatSeed (trom picks the genre, then deep-links) ────────
    if (l.contains('binge')) {
      return const ChatSeedAction(
        "okay what are we feeling — comfort rewatch or something new?",
      );
    }

    // ── 8. Generic watch / movie → YouTube ─────────────────────────────────
    if (_any(l, ['movie', 'watch', 'film'])) {
      return const ExternalUrlAction('https://www.youtube.com/');
    }

    // ── 9. Book → Goodreads ────────────────────────────────────────────────
    if (_any(l, ['read', 'book', 'article'])) {
      return const ExternalUrlAction('https://www.goodreads.com/');
    }

    // ── 10. Recipe / cook → YouTube search ────────────────────────────────
    if (_any(l, ['cook', 'recipe', 'bake', 'make', 'meal', 'warm'])) {
      return ExternalUrlAction(
        'https://www.youtube.com/results?search_query=${Uri.encodeComponent("easy recipes")}',
      );
    }

    // ── 11. Write / reflect → ChatSeed journal ─────────────────────────────
    if (_any(l, ['write', 'reflect', 'breathe', 'reset'])) {
      return ChatSeedAction(_journalSeed(l));
    }

    // ── 12. Focus / productivity → ChatSeed ───────────────────────────────
    if (_any(l, [
      'timer', 'task', 'inbox', 'blocker', 'tomorrow', 'priorities',
      'small', 'putting off', 'tonight', 'one thing', 'stuff',
    ])) {
      return ChatSeedAction(_focusSeed(l));
    }

    // ── 13. Anything else → FailedAction ──────────────────────────────────
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
    if (l.contains('gym') || l.contains('fitness') || l.contains('class')) {
      return 'gym near me';
    }
    if (l.contains('cafe') || l.contains('coffee')) return 'cafe near me';
    if (l.contains('hike') || l.contains('trail') || l.contains('outdoor')) {
      return 'hiking trails near me';
    }
    if (l.contains('hair') || l.contains('nails') || l.contains('salon')) {
      return 'beauty salon near me';
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
