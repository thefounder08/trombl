import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/trombl_theme.dart';
import 'menu_data.dart';
import 'menu_models.dart';

enum ActionResult { launched, dndInternal, comingSoon, failed }

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

/// Maps string tags → real-world actions.
///
/// Five functional tags (all others return [ActionResult.comingSoon]):
///   discover  → BookMyShow search URL (query inferred from label keywords)
///   squad     → WhatsApp wa.me with trom-drafted message
///   order in  → Zomato search URL (cuisine inferred from label)
///   rest      → dndInternal (no URL — caller routes to /dnd)
///   content   → Instagram
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
  };

  /// The [ActionDefinition] for [tag], or null if not actionable.
  static ActionDefinition? definitionFor(String tag) => _defs[tag];

  /// True when [tag] has a real action wired up.
  static bool isActionable(String tag) => _defs.containsKey(tag);

  /// Execute the action for [option].
  ///
  /// [tromMessage] is the squad WhatsApp draft; auto-generated when null.
  static Future<ActionResult> execute({
    required MenuOption option,
    required String vibe,
    String? tromMessage,
  }) async {
    switch (option.tag) {
      case 'coming soon':
        return ActionResult.comingSoon;
      case 'rest':
        return ActionResult.dndInternal;
      case 'discover':
        return _launchDiscover(option.label);
      case 'squad':
        return _launchSquad(vibe, tromMessage);
      case 'order in':
        return _launchOrderIn(option.label);
      case 'content':
        return _launchContent();
      default:
        return ActionResult.failed;
    }
  }

  // ─── Private launchers ───────────────────────────────────────────────────────

  static Future<ActionResult> _launchDiscover(String label) {
    final lower = label.toLowerCase();
    final query = lower.contains('music') || lower.contains('gig')
        ? 'live music tonight'
        : lower.contains('club')
            ? 'nightclub tonight'
            : lower.contains('comedy')
                ? 'comedy show tonight'
                : lower.contains('concert')
                    ? 'concert tonight'
                    : lower.contains('gym') || lower.contains('fitness')
                        ? 'fitness classes nearby'
                        : lower.contains('hike') || lower.contains('trail')
                            ? 'hiking trails nearby'
                            : lower.contains('hair') || lower.contains('nails')
                                ? 'beauty salon near me'
                                : 'events tonight near me';
    return _tryLaunch(
      'https://in.bookmyshow.com/explore/events?q=${Uri.encodeComponent(query)}',
    );
  }

  static Future<ActionResult> _launchSquad(String vibe, String? tromMessage) {
    final msg = tromMessage ?? TromblMenu.squadMessage(vibe);
    return _tryLaunch('https://wa.me/?text=${Uri.encodeComponent(msg)}');
  }

  static Future<ActionResult> _launchOrderIn(String label) {
    final lower = label.toLowerCase();
    final cuisine = lower.contains('snack')
        ? 'snacks'
        : lower.contains('coffee')
            ? 'coffee'
            : lower.contains('dessert') || lower.contains('bake')
                ? 'dessert'
                : lower.contains('dinner')
                    ? 'dinner'
                    : 'comfort food';
    return _tryLaunch(
      'https://www.zomato.com/search?q=${Uri.encodeComponent(cuisine)}',
    );
  }

  static Future<ActionResult> _launchContent() =>
      _tryLaunch('https://www.instagram.com/');

  static Future<ActionResult> _tryLaunch(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return ActionResult.launched;
      }
      return ActionResult.failed;
    } catch (_) {
      return ActionResult.failed;
    }
  }
}
