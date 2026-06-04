import 'package:flutter/foundation.dart';

import '../action/action_library.dart';
import '../archetype/archetype_models.dart';
import '../context/context_models.dart';
import '../memory/memory_engine.dart';
import '../open_loops/open_loop_engine.dart';
import '../open_loops/open_loop_models.dart';
import '../scoring/gemini_scoring_engine.dart';
import 'recommendation_models.dart';

/// The main decision pipeline.
///
/// Flow:
/// 1. Filter action catalog for current context
/// 2. Apply open-loop boosts
/// 3. Send to Gemini for scoring
/// 4. Apply memory penalties (repeated ignores → deprioritise)
/// 5. Rank + return top 5
class RecommendationEngine {
  RecommendationEngine({
    required GeminiScoringEngine scoringEngine,
    required MemoryEngine memory,
  })  : _scoring = scoringEngine,
        _memory = memory;

  final GeminiScoringEngine _scoring;
  final MemoryEngine _memory;

  static const _maxCandidates = 12;
  static const _topN = 5;

  Future<RecommendationSet> recommend({
    required ContextSnapshot context,
    required ArchetypeScores archetypes,
    required List<OpenLoop> openLoops,
    required List<String> recentlyShown,
  }) async {
    // 1. Filter catalog for this context
    final candidates = ActionLibrary.forContext(context.period, context.vibe)
        .take(_maxCandidates)
        .toList();

    if (candidates.isEmpty) {
      debugPrint('[RecoEngine] no candidates — returning empty');
      return RecommendationSet(
        picks: [],
        context: context,
        generatedAt: DateTime.now(),
      );
    }

    debugPrint('[RecoEngine] ${candidates.length} candidates for '
        '${context.period.name} / ${context.vibe}');

    // 2. Open-loop boosts (pre-scoring signal)
    final loopBoosts = OpenLoopEngine.computeBoosts(openLoops);
    if (loopBoosts.isNotEmpty) {
      debugPrint('[RecoEngine] loop boosts: $loopBoosts');
    }

    // 3. Gemini scoring
    final scoring = await _scoring.score(
      candidates: candidates,
      context: context,
      archetypes: archetypes,
      openLoops: openLoops,
      recentlyShown: recentlyShown,
    );

    // 4. Merge scores: Gemini score + open-loop boost
    final merged = Map<String, double>.from(scoring.scores);
    for (final entry in loopBoosts.entries) {
      merged[entry.key] = (merged[entry.key] ?? 0) + entry.value;
    }

    // 5. Memory penalties
    final penalised = _memory.applyPenalties(merged);

    // 6. Rank
    final sorted = candidates
        .map((a) => (action: a, score: penalised[a.id] ?? 0))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final picks = sorted.take(_topN).toList().asMap().entries.map((e) {
      return Recommendation(
        action: e.value.action,
        score: e.value.score,
        rank: e.key + 1,
      );
    }).toList();

    debugPrint('[RecoEngine] top pick: ${picks.first.action.id} '
        '(score=${picks.first.score.toStringAsFixed(1)})');

    return RecommendationSet(
      picks: picks,
      context: context,
      generatedAt: DateTime.now(),
    );
  }
}
