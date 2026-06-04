/// Result of a Gemini scoring call.
class ScoredAction {
  const ScoredAction({required this.actionId, required this.score});
  final String actionId;
  final double score; // 0–10

  @override
  String toString() => 'ScoredAction($actionId: $score)';
}

/// Full scoring result for a batch of candidate actions.
class ScoringResult {
  const ScoringResult({
    required this.scores,
    required this.rankedIds,
    required this.rawJson,
  });

  final Map<String, double> scores;
  final List<String> rankedIds; // sorted descending by score
  final String rawJson;

  double scoreFor(String id) => scores[id] ?? 0;
}
