import 'open_loop_models.dart';

/// Boosts candidate actions that relate to open loops.
///
/// If the user has an open loop "call mom" and an action "call someone you
/// owe a call" is in candidates, that action's score gets a priority bump.
abstract final class OpenLoopEngine {
  static const _defaultBoost = 2.5;

  /// Returns a map of actionId → boost score from open loops.
  static Map<String, double> computeBoosts(List<OpenLoop> openLoops) {
    final boosts = <String, double>{};
    for (final loop in openLoops.where((l) => l.isOpen)) {
      final related = _findRelatedActions(loop.title);
      final boost = _defaultBoost * loop.priority;
      for (final actionId in related) {
        boosts[actionId] = (boosts[actionId] ?? 0) + boost;
      }
    }
    return boosts;
  }

  /// Produce a prompt hint about open loops.
  static String toPromptHint(List<OpenLoop> openLoops) {
    final open = openLoops.where((l) => l.isOpen).take(3).toList();
    if (open.isEmpty) return '';
    final items = open.map((l) => '"${l.title}"').join(', ');
    return 'user has open loops they haven\'t done yet: $items. '
        'if relevant, bias toward completing these.';
  }

  // ─── Private ─────────────────────────────────────────────────────────────

  static const _keywords = <String, List<String>>{
    'call_someone': ['call', 'phone', 'ring', 'talk'],
    'reach_one_person': ['text', 'message', 'reach', 'dm'],
    'apply_one_thing': ['apply', 'submit', 'application', 'send'],
    'portfolio_update': ['portfolio', 'resume', 'cv', 'profile'],
    'ship_one_thing': ['ship', 'launch', 'finish', 'release', 'build'],
    'check_finances': ['finance', 'bank', 'money', 'budget', 'pay'],
    'workout': ['gym', 'workout', 'exercise', 'run', 'walk'],
  };

  static List<String> _findRelatedActions(String loopTitle) {
    final lower = loopTitle.toLowerCase();
    final result = <String>[];
    for (final entry in _keywords.entries) {
      if (entry.value.any((kw) => lower.contains(kw))) {
        result.add(entry.key);
      }
    }
    return result;
  }
}
