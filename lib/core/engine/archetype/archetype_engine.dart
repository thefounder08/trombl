import 'archetype_models.dart';

/// Derives and updates archetype scores from behavioral signals.
///
/// Score update rules:
/// - Accepted pick with tag X → boost archetypes that own tag X by +3
/// - Rejected (rerolled) pick → penalise archetypes that own that tag by -1
/// - Score capped [0, 100]
abstract final class ArchetypeEngine {
  /// Recompute scores from a list of accepted/rerolled pick tags.
  static ArchetypeScores computeFromHistory({
    required List<String> acceptedTags,
    required List<String> rejectedTags,
    ArchetypeScores? baseline,
  }) {
    final base = baseline ?? ArchetypeScores.neutral();
    final scores = Map<Archetype, int>.from(base.rawScores);

    for (final tag in acceptedTags) {
      for (final a in Archetype.values) {
        if (a.boostTags.contains(tag)) {
          scores[a] = (scores[a]! + 3).clamp(0, 100);
        }
      }
    }

    for (final tag in rejectedTags) {
      for (final a in Archetype.values) {
        if (a.boostTags.contains(tag)) {
          scores[a] = (scores[a]! - 1).clamp(0, 100);
        }
      }
    }

    return ArchetypeScores(scores);
  }

  /// Produce a prompt-ready hint string (top 2 archetypes only).
  static String toPromptHint(ArchetypeScores scores) {
    final t = scores.top(2);
    if (t.isEmpty) return '';
    final dominant = t.first.key;
    final secondary = t.length > 1 ? t[1].key : null;

    final buf = StringBuffer(
        'user archetype signals: ${dominant.label}');
    if (secondary != null) {
      buf.write(', secondary ${secondary.label}');
    }
    buf.write('. lean into this in suggestions where relevant.');
    return buf.toString();
  }
}
