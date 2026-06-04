import '../action/action_library.dart';
import '../action/action_models.dart';
import '../context/context_models.dart';

/// JOMO Engine: "What pressure should this user ignore?"
///
/// Returns 1 primary recommendation — what to do instead of going out,
/// responding to everyone, or feeling FOMO about plans they're skipping.
abstract final class JomoEngine {
  static TromblAction recommend({required ContextSnapshot context}) {
    final candidates = ActionLibrary.forContext(context.period, 'jomo')
        .where((a) => a.energyRequired <= 2)
        .toList();

    if (candidates.isEmpty) {
      return ActionLibrary.byId('pick_show_commit') ??
          ActionLibrary.all.firstWhere((a) => a.tags.contains('rest'));
    }

    // Prefer low-energy, solo, rest activities — the jomo sweet spot
    final scored = candidates.map((a) {
      var score = 0.0;
      if (a.tags.contains('rest')) { score += 3; }
      if (a.socialRequired == 1) { score += 2; }
      if (a.energyRequired == 1) { score += 2; }
      if (a.category == ActionCategory.selfcare) { score += 1; }
      if (a.category == ActionCategory.entertainment) { score += 1; }
      return (action: a, score: score);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return scored.first.action;
  }

  /// Trom-voiced message for why skipping is valid.
  static String jomoMessage(TromblAction action, String vibe) {
    return switch (action.category) {
      ActionCategory.selfcare =>
        "u don't owe anyone ur energy tonight. ${action.description}",
      ActionCategory.entertainment =>
        "staying in is a valid choice. ${action.description}",
      _ => "protect ur peace. ${action.description}",
    };
  }
}
