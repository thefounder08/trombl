import 'package:flutter/foundation.dart';

import '../../../core/engine/context/human_rhythm_engine.dart';
import '../data/decide_repository.dart';
import 'ai_pick_model.dart';

enum _Depth { thin, some, rich }

/// Builds the LLM prompt for a single pick.
///
/// Architecture: Gemini receives the Layer 1 candidate set from
/// HumanRhythmEngine and picks the BEST ONE — no free generation.
/// Mood text is the PRIMARY override: when present it injects
/// mood-matched candidates at the top of the list and re-anchors the
/// system instruction so the AI cannot ignore it.
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
    final timeCandidates = HumanRhythmEngine.candidatesFor(period, vibe);

    // Mood candidates prepended — so the AI sees them before time candidates.
    final moodCandidates = moodText != null && moodText.isNotEmpty
        ? _moodCandidates(moodText)
        : <String>[];
    final candidates = [...moodCandidates, ...timeCandidates];

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
      hasMoodCandidates: moodCandidates.isNotEmpty,
      depth: depth,
      sessionCount: ctx.sessionCount,
      rerollCount: rerollCount,
      inSessionRejects: inSessionRejects,
      recentPicks: ctx.recentPicks,
      moodText: moodText,
      weatherCondition: weatherCondition,
    );

    // Log the full prompt so mood injection can be verified.
    if (moodText != null && moodText.isNotEmpty) {
      debugPrint('[PickPrompt] MOOD OVERRIDE: "$moodText" → injected ${moodCandidates.length} mood candidates: $moodCandidates');
    }
    debugPrint('[PickPrompt] full prompt sent to Gemini:\n$userPrompt');

    return (system: _system, userPrompt: userPrompt);
  }

  // ─── Mood keyword → candidate injection ──────────────────────────────────────
  // When the user types a mood, these candidates are prepended to the time-based
  // list so the AI has mood-appropriate options available and will pick one.

  static List<String> _moodCandidates(String mood) {
    final m = mood.toLowerCase();
    final out = <String>[];

    // Audio / listening
    if (_any(m, ['listen', 'music', 'podcast', 'audio', 'song', 'sound', 'playlist', 'spotify', 'ambient'])) {
      out.addAll(['put on a podcast', 'play music', 'ambient sounds', 'find a playlist that fits the mood']);
    }
    // Hunger / food
    if (_any(m, ['hungry', 'hunger', 'eat', 'food', 'snack', 'meal', 'starving', 'lunch', 'dinner', 'breakfast', 'cook'])) {
      out.addAll(['order food delivery', 'make something simple to eat', 'go grab food', 'find a snack right now']);
    }
    // Working / focus
    if (_any(m, ['working', 'work', 'focus', 'productive', 'busy', 'study', 'studying'])) {
      out.addAll(['set a 25-min focus timer', 'get up and stretch before sitting back down', 'make a drink and reset']);
    }
    // Bored
    if (_any(m, ['bored', 'boring', 'nothing to do', 'dull'])) {
      out.addAll(['do something you\'ve been putting off', 'learn one random thing', 'find something new to watch', 'call someone you haven\'t in a while']);
    }
    // Tired but restless / can't sleep
    if (_any(m, ['can\'t sleep', 'cant sleep', 'restless', 'insomnia', 'awake', 'up late', 'wired'])) {
      out.addAll(['no-screen wind-down for 10', 'breathing exercise', 'audiobook or calm podcast']);
    }
    // Tired / sleepy (but not restless)
    if (_any(m, ['tired', 'sleepy', 'exhausted', 'drained', 'no energy'])) {
      out.addAll(['just lie down', 'body scan meditation', 'wind-down screen off']);
    }
    // Anxious / stressed
    if (_any(m, ['anxious', 'anxiety', 'stressed', 'stress', 'overwhelmed', 'nervous', 'worried'])) {
      out.addAll(['step outside for 5', 'breathing exercise', 'take a proper break from everything']);
    }
    // Lonely / social
    if (_any(m, ['lonely', 'alone', 'miss', 'want company', 'need someone'])) {
      out.addAll(['text someone you miss', 'voice note a friend', 'make plans with someone this week']);
    }
    // Movement / exercise
    if (_any(m, ['move', 'exercise', 'workout', 'gym', 'run', 'walk', 'active', 'fitness'])) {
      out.addAll(['go for a quick walk', '10-min home workout', 'get outside and move']);
    }
    // Sad / low mood
    if (_any(m, ['sad', 'down', 'low', 'unhappy', 'miserable', 'depressed'])) {
      out.addAll(['text someone you trust', 'comfort show or movie', 'get outside for 10']);
    }

    return out;
  }

  static bool _any(String mood, List<String> keywords) =>
      keywords.any((k) => mood.contains(k));

  // ─── System prompt ────────────────────────────────────────────────────────────

  static const _system = '''
you are trom. pick the BEST candidate for the user right now.

MOOD OVERRIDE RULE — highest priority, no exceptions:
when the prompt starts with "USER SAID:", that is the MOST IMPORTANT SIGNAL.
you MUST pick something that DIRECTLY addresses what the user said.
- "hungry" or any food signal → pick a food candidate. always.
- "want to listen" or any audio signal → pick an audio candidate (podcast/music/sounds). always.
- "tired but can't sleep" or restless signal → wind-down, not sleep. acknowledge the restless state.
- "bored" → something engaging and stimulating, not rest.
- "working" → focus-aware: timer, break, reset — not social activities.
ignore time rules when the mood is specific and clear. mood wins.

HARD RULES:
- respond with ONLY a valid JSON object. nothing before it. nothing after it.
- NEVER ask a question back. candidates → decision. absolute.
- pick from the candidates list (mood-matched candidates appear first when mood is present).
- ONE pick only. no lists. no alternatives. one confident thing.
- rewrite the candidate label in trom voice (short, punchy, like a text from a friend).
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

  // ─── User prompt ──────────────────────────────────────────────────────────────

  static String _userPrompt({
    required String vibe,
    required int hour,
    required String dayOfWeek,
    String? city,
    required List<String> candidates,
    required bool hasMoodCandidates,
    required _Depth depth,
    required int sessionCount,
    required int rerollCount,
    required List<String> inSessionRejects,
    required List<AiPick> recentPicks,
    String? moodText,
    String? weatherCondition,
  }) {
    final buf = StringBuffer();

    // ── MOOD — absolute first block, strongest signal ─────────────────────────
    if (moodText != null && moodText.isNotEmpty) {
      buf.writeln('USER SAID: "$moodText"');
      buf.writeln('This is the most important signal. Respond to THIS specifically, not to a general vibe.');
      if (hasMoodCandidates) {
        buf.writeln('Mood-matched candidates appear first in [CANDIDATES]. Prefer them.');
      }
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
      buf.writeln('city: $city — give a method not a venue name');
      buf.writeln();
    }

    if (weatherCondition != null &&
        weatherCondition != 'clear' &&
        weatherCondition != 'cloudy') {
      // Mood overrides weather for audio/food (fine indoors regardless of weather)
      final moodOverridesWeather = moodText != null &&
          _any(moodText.toLowerCase(), ['listen', 'music', 'podcast', 'audio', 'hungry', 'eat', 'food']);
      if (!moodOverridesWeather) {
        buf.writeln('[WEATHER]');
        buf.writeln('$weatherCondition — avoid outdoor activities.');
        buf.writeln();
      }
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
      buf.writeln('[REJECTED THIS SESSION — pick something genuinely different]');
      buf.writeln(inSessionRejects.take(3).join(', '));
      buf.writeln();
    }

    if (rerollCount == 1) {
      buf.writeln('note: second pick — vary meaningfully from the first. different type.');
    } else if (rerollCount >= 2) {
      buf.writeln('note: $rerollCount rerolls — try a completely different category.');
    }

    buf.writeln('[VIBE]');
    buf.writeln('vibe: $vibe');
    buf.writeln();

    buf.writeln('pick exactly one candidate. rewrite it in trom voice. specific and actionable.');
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
