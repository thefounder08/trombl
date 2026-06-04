/// User archetypes — each has a score 0–100 derived from behavior.
library;

enum Archetype {
  builder,          // ships things, productive, goal-driven
  socialButterfly,  // people-first, plans, squad energy
  mainCharacter,    // experiences, adventure, FOMO peak
  cozyGoblin,       // comfort, rest, home energy
  doomScroller,     // passive consumption, phone-heavy
  explorer,         // discovery, novelty, curiosity
}

extension ArchetypeExt on Archetype {
  String get label => switch (this) {
        Archetype.builder         => 'Builder',
        Archetype.socialButterfly => 'Social Butterfly',
        Archetype.mainCharacter   => 'Main Character',
        Archetype.cozyGoblin      => 'Cozy Goblin',
        Archetype.doomScroller    => 'Doom Scroller',
        Archetype.explorer        => 'Explorer',
      };

  /// Tags from ai_picks + menu picks that boost this archetype's score.
  List<String> get boostTags => switch (this) {
        Archetype.builder         => ['content', 'solo'],
        Archetype.socialButterfly => ['squad'],
        Archetype.mainCharacter   => ['discover', 'squad'],
        Archetype.cozyGoblin      => ['rest', 'order in'],
        Archetype.doomScroller    => ['rest'],
        Archetype.explorer        => ['discover', 'solo'],
      };
}

/// A snapshot of all archetype scores for a user.
class ArchetypeScores {
  const ArchetypeScores(this._scores);

  factory ArchetypeScores.neutral() => ArchetypeScores(
        Map.fromEntries(Archetype.values.map((a) => MapEntry(a, 50))),
      );

  factory ArchetypeScores.fromJson(Map<String, dynamic> json) {
    final scores = <Archetype, int>{};
    for (final a in Archetype.values) {
      scores[a] = (json[a.name] as num?)?.toInt() ?? 50;
    }
    return ArchetypeScores(scores);
  }

  final Map<Archetype, int> _scores;

  Map<Archetype, int> get rawScores => Map.unmodifiable(_scores);

  int operator [](Archetype a) => _scores[a] ?? 50;

  Archetype get dominant => _scores.entries
      .reduce((a, b) => a.value > b.value ? a : b)
      .key;

  Map<String, dynamic> toJson() =>
      _scores.map((k, v) => MapEntry(k.name, v));

  /// Top N archetypes sorted descending.
  List<MapEntry<Archetype, int>> top(int n) {
    final sorted = _scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).toList();
  }

  /// Human-readable prompt fragment — top 2 archetypes only.
  String toPromptHint() {
    final t = top(2);
    if (t.isEmpty) return '';
    return t.map((e) => '${e.key.label}(${e.value})').join(', ');
  }

  @override
  String toString() => 'ArchetypeScores(${toPromptHint()})';
}
