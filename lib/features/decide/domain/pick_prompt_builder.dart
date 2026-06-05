import 'package:flutter/foundation.dart';

import '../../../core/engine/context/human_rhythm_engine.dart';
import '../data/decide_repository.dart';
import 'ai_pick_model.dart';

enum _Depth { thin, some, rich }

/// Builds the LLM prompt for a single pick.
///
/// Architecture: Gemini receives the Layer 1 candidate set from
/// HumanRhythmEngine and picks the BEST ONE — no free generation.
/// Mood text is still the primary override signal.
abstract final class PickPromptBuilder {
  static ({String system, String userPrompt}) build({
    required String vibe,
    required int hour,
    required String dayOfWeek,
    String? city,
    required int rerollCount,
    required DecideContext ctx,
    required List<String> inSessionRejects,
    String? moodText,
    String? weatherCondition,
  }) {
    final dayType = HumanRhythmEngine.dayTypeFor(dayOfWeek);
    final period = HumanRhythmEngine.periodFor(hour, dayType);
    final candidates = HumanRhythmEngine.candidatesFor(period, vibe);

    final depth = ctx.sessionCount <= 2
        ? _Depth.thin
        : ctx.sessionCount <= 9
            ? _Depth.some
            : _Depth.rich;

    final userPrompt = _userPrompt(
      vibe: vibe,
      hour: hour,
      dayOfWeek: dayOfWeek,
      city: city,
      candidates: candidates,
      depth: depth,
      sessionCount: ctx.sessionCount,
      rerollCount: rerollCount,
      inSessionRejects: inSessionRejects,
      recentPicks: ctx.recentPicks,
      moodText: moodText,
      weatherCondition: weatherCondition,
    );

    debugPrint('[PickPrompt] system chars=${_system.length}');
    debugPrint('[PickPrompt] user prompt:\n$userPrompt');

    return (system: _system, userPrompt: userPrompt);
  }

  static const _system = '''
you are trom. pick the BEST candidate for the user right now.

HARD RULES — no exceptions:
- respond with ONLY a valid JSON object. nothing before it. nothing after it.
- NEVER ask a question back. candidates → decision. absolute.
- pick from the candidates list — do not invent new activities.
- ONE pick only. no lists. no alternatives. one confident thing.
- rewrite the candidate label in trom voice (short, punchy, like a text from a friend)
- no hedging ("maybe", "you might like"). pick and commit.
- no specific venue names — give methods ("closest bar on maps", not a real bar name).
- all string values lowercase. no markdown.

respond exactly this shape:
{"pick":"<trom-voice label, 6 words max>","reason":"<why right now, 10 words max, trom voice>","tag":"<discover|squad|order in|rest|content|solo>"}

tags:
- discover: find a place/event via maps or booking
- squad: text or call someone
- order in: food or delivery app
- rest: wind down, sleep aids, recharge, quiet time
- content: create or post something
- solo: do it alone, no app needed
''';

  static String _userPrompt({
    required String vibe,
    required int hour,
    required String dayOfWeek,
    String? city,
    required List<String> candidates,
    required _Depth depth,
    required int sessionCount,
    required int rerollCount,
    required List<String> inSessionRejects,
    required List<AiPick> recentPicks,
    String? moodText,
    String? weatherCondition,
  }) {
    final buf = StringBuffer();

    // Mood — absolute first line, highest weight
    if (moodText != null && moodText.isNotEmpty) {
      buf.writeln('mood (highest priority): "$moodText" — reflect this in the pick.');
      buf.writeln();
    }

    buf.writeln('[TIME]');
    buf.writeln('${dayOfWeek.toUpperCase()}, ${_hourLabel(hour)} — ${_dayType(dayOfWeek)}');
    buf.writeln();

    buf.writeln('[CANDIDATES]');
    buf.writeln(candidates.join(', '));
    buf.writeln();

    if (city != null && city.isNotEmpty) {
      buf.writeln('[LOCATION]');
      buf.writeln(
          "city: $city — give a method not a venue name");
      buf.writeln();
    }

    if (weatherCondition != null &&
        weatherCondition != 'clear' &&
        weatherCondition != 'cloudy') {
      buf.writeln('[WEATHER]');
      buf.writeln('$weatherCondition — avoid outdoor activities.');
      buf.writeln();
    }

    // Personalisation
    switch (depth) {
      case _Depth.thin:
        if (sessionCount == 0) {
          buf.writeln('[HISTORY]');
          buf.writeln('first ever session — start reason with: "we just met so i\'m guessing —"');
          buf.writeln();
        }
      case _Depth.some:
      case _Depth.rich:
        final pattern = _patternSummary(recentPicks);
        if (pattern.isNotEmpty) {
          buf.writeln('[HISTORY]');
          buf.writeln(pattern);
          buf.writeln();
        }
    }

    if (inSessionRejects.isNotEmpty) {
      buf.writeln(
          '[REJECTED THIS SESSION — pick something genuinely different]');
      buf.writeln(inSessionRejects.take(3).join(', '));
      buf.writeln();
    }

    if (rerollCount == 1) {
      buf.writeln(
          'note: second pick — vary meaningfully from the first. different type.');
    } else if (rerollCount >= 2) {
      buf.writeln(
          'note: $rerollCount rerolls — try a completely different category.');
    }

    buf.writeln('[VIBE]');
    buf.writeln('vibe: $vibe');
    buf.writeln();

    buf.writeln(
        'pick exactly one candidate. rewrite it in trom voice. specific and actionable.');
    return buf.toString().trim();
  }

  static String _hourLabel(int hour) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final amPm = hour < 12 ? 'am' : 'pm';
    return '$h$amPm';
  }

  static String _dayType(String dayOfWeek) => switch (dayOfWeek) {
        'fri' || 'sat' => 'weekend — social/higher energy ok',
        'sun' => 'sunday — easing into the week',
        _ => 'weekday',
      };

  static String _patternSummary(List<AiPick> picks) {
    if (picks.isEmpty) return '';
    final loved =
        picks.where((p) => p.accepted).map((p) => p.pickText).take(3).toList();
    final skipped =
        picks.where((p) => p.rerolled).map((p) => p.pickText).take(3).toList();
    final parts = <String>[];
    if (loved.isNotEmpty) parts.add('loved: ${loved.join(", ")}');
    if (skipped.isNotEmpty) parts.add('skipped: ${skipped.join(", ")}');
    return parts.join('. ');
  }
}
