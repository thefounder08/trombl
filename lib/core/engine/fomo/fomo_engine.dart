import '../action/action_library.dart';
import '../action/action_models.dart';
import '../archetype/archetype_models.dart';
import '../context/context_models.dart';

/// FOMO Engine: "What high-upside thing is this user avoiding?"
///
/// Returns 1 primary + 2 backup actions the user should stop avoiding.
/// Used when fomo is the vibe and the user wants to be pushed.
abstract final class FomoEngine {
  /// Derive FOMO push actions from context + archetype.
  static ({TromblAction primary, List<TromblAction> backups}) recommend({
    required ContextSnapshot context,
    required ArchetypeScores archetypes,
  }) {
    final candidates = ActionLibrary.forContext(context.period, 'fomo');
    final sorted = _rank(candidates, context, archetypes);

    final primary = sorted.isNotEmpty
        ? sorted.first
        : ActionLibrary.byId('leave_no_plan') ?? candidates.first;

    final backups = sorted
        .skip(1)
        .take(2)
        .toList();

    return (primary: primary, backups: backups);
  }

  static List<TromblAction> _rank(
    List<TromblAction> candidates,
    ContextSnapshot context,
    ArchetypeScores archetypes,
  ) {
    // Score = archetype alignment + energy match + social fit
    final scored = candidates.map((a) {
      var score = 0.0;

      // Archetype alignment
      final dominant = archetypes.dominant;
      if (dominant.boostTags.any((t) => a.tags.contains(t))) { score += 3; }

      // Prime time → prefer social/adventure
      if (context.period == TimePeriod.primeTime) {
        if (a.category == ActionCategory.social ||
            a.category == ActionCategory.adventure) { score += 2; }
      }

      // Boost discovery for explorer archetype
      if (archetypes[Archetype.explorer] > 65 &&
          a.tags.contains('discover')) { score += 2; }

      // Boost social for social butterfly
      if (archetypes[Archetype.socialButterfly] > 65 &&
          a.tags.contains('squad')) { score += 2; }

      return (action: a, score: score);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return scored.map((s) => s.action).toList();
  }
}
