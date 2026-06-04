import '../action/action_models.dart';
import '../archetype/archetype_models.dart';
import '../context/context_models.dart';
import '../open_loops/open_loop_models.dart';

/// All inputs assembled before scoring.
class RecommendationContext {
  const RecommendationContext({
    required this.context,
    required this.archetypes,
    required this.openLoops,
    required this.candidates,
    required this.recentlyShown,
  });

  final ContextSnapshot context;
  final ArchetypeScores archetypes;
  final List<OpenLoop> openLoops;
  final List<TromblAction> candidates;

  /// Action IDs shown in recent sessions (used for diversity).
  final List<String> recentlyShown;
}

/// A single item in the final ranked recommendation list.
class Recommendation {
  const Recommendation({
    required this.action,
    required this.score,
    required this.rank,
  });

  final TromblAction action;
  final double score;
  final int rank; // 1 = top pick

  @override
  String toString() =>
      'Recommendation(#$rank ${action.id} score=$score)';
}

/// The final output of the Recommendation Engine.
class RecommendationSet {
  const RecommendationSet({
    required this.picks,
    required this.context,
    required this.generatedAt,
  });

  final List<Recommendation> picks; // up to 5, ranked
  final ContextSnapshot context;
  final DateTime generatedAt;

  Recommendation? get top => picks.isEmpty ? null : picks.first;

  bool get isEmpty => picks.isEmpty;

  @override
  String toString() =>
      'RecommendationSet(${picks.length} picks, top=${top?.action.id})';
}
