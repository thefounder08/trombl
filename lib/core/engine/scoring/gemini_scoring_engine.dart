import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/ai/llm_provider.dart';
import '../../../core/ai/models/llm_message.dart';
import '../../../shared/result.dart';
import '../action/action_models.dart';
import '../archetype/archetype_models.dart';
import '../context/context_models.dart';
import '../open_loops/open_loop_models.dart';
import 'scoring_models.dart';

/// Sends candidate actions + full context to Gemini, receives numeric scores.
///
/// IMPORTANT: We NEVER ask Gemini "what should the user do?"
/// We ask: "here are candidates — score each 0-10 for this user right now."
/// The engine decides what to show. Gemini only scores.
class GeminiScoringEngine {
  const GeminiScoringEngine(this._llm);
  final LlmProvider _llm;

  static const _system =
      'You are a scoring engine. Return ONLY a valid JSON object. '
      'No markdown, no commentary, nothing before or after the JSON.';

  Future<ScoringResult> score({
    required List<TromblAction> candidates,
    required ContextSnapshot context,
    required ArchetypeScores archetypes,
    required List<OpenLoop> openLoops,
    required List<String> recentlyShown,
  }) async {
    if (candidates.isEmpty) {
      return const ScoringResult(scores: {}, rankedIds: [], rawJson: '{}');
    }

    final prompt = _buildPrompt(
      candidates: candidates,
      context: context,
      archetypes: archetypes,
      openLoops: openLoops,
      recentlyShown: recentlyShown,
    );

    debugPrint('[ScoringEngine] scoring ${candidates.length} candidates');
    debugPrint('[ScoringEngine] mood=${context.moodText} '
        'period=${context.period.name} vibe=${context.vibe}');
    debugPrint('[ScoringEngine] prompt chars=${prompt.length}');

    final result = await _llm.generate(
      LlmRequest(system: _system, prompt: prompt),
    );

    return switch (result) {
      Success(:final data) => _parse(data, candidates),
      Failure() => _fallback(candidates),
    };
  }

  // ─── Prompt construction ──────────────────────────────────────────────────

  String _buildPrompt({
    required List<TromblAction> candidates,
    required ContextSnapshot context,
    required ArchetypeScores archetypes,
    required List<OpenLoop> openLoops,
    required List<String> recentlyShown,
  }) {
    final buf = StringBuffer();

    // User state
    if (context.hasMood) {
      buf.writeln('user mood (highest priority): "${context.moodText}"');
    }
    buf.writeln('time: ${context.dayOfWeek} ${context.hour}:00 '
        '(${context.period.name})');
    buf.writeln('vibe: ${context.vibe}');
    if (context.weather != null) {
      buf.writeln('weather: ${context.weather}');
    }

    // Archetype hint
    final archHint = archetypes.toPromptHint();
    if (archHint.isNotEmpty) buf.writeln('archetypes: $archHint');

    // Open loops
    final openHint = openLoops
        .where((l) => l.isOpen)
        .take(3)
        .map((l) => l.title)
        .join(', ');
    if (openHint.isNotEmpty) {
      buf.writeln('open loops (incomplete commitments): $openHint');
    }

    // Anti-repeat
    if (recentlyShown.isNotEmpty) {
      buf.writeln('recently shown (score these lower to add variety): '
          '${recentlyShown.take(5).join(", ")}');
    }

    // Rhythm context
    buf.writeln();
    buf.writeln('human rhythm for this moment: ${context.rhythm.directive}');
    buf.writeln();

    // Candidates
    buf.writeln('score each candidate action 0-10 for this user right now:');
    for (final a in candidates) {
      buf.writeln('  ${a.id}: ${a.title} — ${a.description}');
    }

    buf.writeln();
    buf.writeln(
        'return exactly: {"${candidates.first.id}": 7.5, ...} — one key per action id.');

    return buf.toString().trim();
  }

  // ─── Response parsing ─────────────────────────────────────────────────────

  ScoringResult _parse(String raw, List<TromblAction> candidates) {
    try {
      final clean = raw
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}');
      if (start == -1 || end <= start) throw const FormatException('no JSON');
      final json = jsonDecode(clean.substring(start, end + 1))
          as Map<String, dynamic>;

      final scores = <String, double>{};
      for (final entry in json.entries) {
        final score = (entry.value as num?)?.toDouble();
        if (score != null) scores[entry.key] = score.clamp(0.0, 10.0);
      }

      final ranked = scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      debugPrint('[ScoringEngine] parsed ${scores.length} scores. '
          'top: ${ranked.take(3).map((e) => "${e.key}:${e.value}").join(", ")}');

      return ScoringResult(
        scores: scores,
        rankedIds: ranked.map((e) => e.key).toList(),
        rawJson: clean,
      );
    } catch (e) {
      debugPrint('[ScoringEngine] parse error: $e — fallback');
      return _fallback(candidates);
    }
  }

  ScoringResult _fallback(List<TromblAction> candidates) {
    final scores = <String, double>{};
    for (var i = 0; i < candidates.length; i++) {
      scores[candidates[i].id] = (candidates.length - i).toDouble();
    }
    return ScoringResult(
      scores: scores,
      rankedIds: candidates.map((a) => a.id).toList(),
      rawJson: '{}',
    );
  }
}
