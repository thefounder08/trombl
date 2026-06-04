import 'package:flutter/foundation.dart';

import '../data/decide_repository.dart';
import 'ai_pick_model.dart';

enum _Depth { thin, some, rich }

/// Builds the LLM prompt for a single pick using a 4-tier constraint hierarchy.
///
/// Tier order (each tier overrides/constrains everything below it):
///   1. PRIMARY DRIVERS  — mood text (most important) + exact time/day
///   2. HARD FILTERS     — time-block rules, weather, location
///   3. PERSONALIZERS    — history patterns, anti-repetition
///   4. USER-TOLD-ONLY   — energy/budget/state only from mood text, never assumed
///
/// Day-rhythm rules (Mon-Fri vs weekend) are part of Tier 2 hard filters.
/// Mood text OVERRIDES rhythm if the user says "day off" / "working late" etc.
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
you are trom. pick ONE thing for the user to do right now.

HARD RULES — no exceptions:
- respond with ONLY a valid JSON object. nothing before it. nothing after it.
- NEVER ask a question back. input → decision. this is absolute.
- ONE pick only. no lists. no alternatives. one confident thing.
- no hedging ("maybe", "you might like", "could try"). pick and commit.
- no specific venue names — give methods ("closest bar on maps", not a real bar name).
- all string values lowercase. no markdown. no bullets inside strings.
- trom voice: short, punchy, honest, warm — like a text from a real friend, not an app.
- the pick must be actionable given EVERY constraint in the user prompt.
- VARY your output — do NOT default to the same safe answer. if "get outside" or "go for a walk" was recent, suggest something different.

respond exactly this shape:
{"pick":"<activity, 6 words max>","reason":"<why right now, 10 words max, trom voice>","tag":"<discover|squad|order in|rest|content|solo>"}

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
    required _Depth depth,
    required int sessionCount,
    required int rerollCount,
    required List<String> inSessionRejects,
    required List<AiPick> recentPicks,
    String? moodText,
    String? weatherCondition,
  }) {
    final buf = StringBuffer();

    // ─── TIER 1: Mood — absolute first line, highest weight ───────────────────
    if (moodText != null && moodText.isNotEmpty) {
      buf.writeln('⚠️ MOOD OVERRIDE — READ FIRST, HIGHEST PRIORITY:');
      buf.writeln('The user said: "$moodText"');
      buf.writeln('This is the most important signal. Respond to this SPECIFICALLY.');
      buf.writeln('The word(s) in the mood MUST be reflected in the pick and reason.');
      buf.writeln('If mood mentions work/focus/tasks → pick work-compatible activity.');
      buf.writeln('If mood says "day off" or similar → ignore work-hours restrictions below.');
      buf.writeln();
    }

    // Time context
    buf.writeln('[TIME]');
    buf.writeln('${dayOfWeek.toUpperCase()}, ${_hourLabel(hour)} — ${_dayType(dayOfWeek)}');
    buf.writeln();

    // ─── TIER 2: Hard filters — day-rhythm, weather, location ─────────────────
    buf.writeln('[DAY-RHYTHM RULES — obey unless mood above says otherwise]');
    buf.writeln(_timeBlock(hour, dayOfWeek));
    buf.writeln();

    final isOutdoorBlocked = _isOutdoorBlocked(hour, dayOfWeek, weatherCondition);
    if (isOutdoorBlocked) {
      buf.writeln('[OUTDOOR BLOCK]');
      if (weatherCondition != null &&
          weatherCondition != 'clear' &&
          weatherCondition != 'cloudy') {
        buf.writeln('weather: $weatherCondition — do NOT suggest outdoor activities.');
      }
      buf.writeln();
    }

    if (city != null && city.isNotEmpty) {
      buf.writeln('[LOCATION]');
      buf.writeln(
          "city: $city — give a method not a venue name (e.g. \"closest open spot on maps, don't scroll past #3\")");
      buf.writeln();
    }

    // ─── TIER 3: Personalizers — history, anti-repetition ────────────────────
    switch (depth) {
      case _Depth.thin:
        if (sessionCount == 0) {
          buf.writeln('[HISTORY]');
          buf.writeln('first ever session — no history exists yet.');
          buf.writeln('start the reason with: "we just met so i\'m guessing —"');
          buf.writeln();
        }
      case _Depth.some:
      case _Depth.rich:
        final pattern = _patternSummary(recentPicks);
        if (pattern.isNotEmpty) {
          buf.writeln('[HISTORY]');
          buf.writeln(pattern);
          if (depth == _Depth.rich) {
            buf.writeln(
                'trom knows this person — can lightly reference their pattern in the reason if relevant.');
          }
          buf.writeln();
        }
    }

    if (inSessionRejects.isNotEmpty) {
      buf.writeln('[ALREADY REJECTED THIS SESSION — do not suggest these, pick something genuinely different]');
      buf.writeln(inSessionRejects.join(', '));
      buf.writeln();
    }

    if (rerollCount == 1) {
      buf.writeln('note: second pick — vary meaningfully from the first. different activity type.');
    } else if (rerollCount >= 2) {
      buf.writeln(
          'note: $rerollCount rerolls — acknowledge in reason, start with "ok not feeling it —". try a completely different category.');
    }

    // Vibe as final fallback signal
    buf.writeln('[VIBE — fallback signal, only matters if no mood text above]');
    buf.writeln('vibe: $vibe');
    buf.writeln();

    buf.writeln('pick exactly one thing. specific. actionable. valid against every constraint above.');
    return buf.toString().trim();
  }

  // ─── Day-rhythm time block (Tier 2) ───────────────────────────────────────

  static String _timeBlock(int hour, String dayOfWeek) {
    final isWeekend = dayOfWeek == 'sat' || dayOfWeek == 'sun';
    final isWeekday = !isWeekend;

    // Deep night — no exceptions regardless of day
    if (hour >= 0 && hour < 5) {
      return '''current block: 12am–5am — DEEP NIGHT
FORBIDDEN (no exceptions): going outside, contacting people, high-energy activities, bars, clubs, restaurants, errands.
ONLY suggest: wind-down (dim lights, no screens), sleep aids (breathing, lying in dark), quiet solo comfort (warm drink, quiet audio).
If they say they can't sleep: give real wind-down advice — NEVER "go for a walk" or "text someone".''';
    }

    // Early morning (any day)
    if (hour >= 5 && hour < 9) {
      return '''current block: 5–9am — early morning
OK: gentle movement, slow coffee/breakfast, sunlight, journaling, easing in.
NOT OK: bars, clubs, nightlife, heavy commitments, rushing anywhere.''';
    }

    // Work hours — ONLY on weekdays
    if (isWeekday && hour >= 9 && hour < 18) {
      return '''current block: ${_hourLabel(hour)} on ${dayOfWeek.toUpperCase()} — WORK HOURS (weekday business day)
ALLOWED: focus sprints, proper lunch, 20-min walk to reset, coffee break, quick errand, productivity boost.
FORBIDDEN (no exceptions unless mood says "day off"): bars, clubs, nightlife, leisure going-out, social plans that take >1 hour, any activity that assumes free time.
If mood says "day off", "not working", "free today": ignore these restrictions entirely — treat as weekend leisure.''';
    }

    // Weekend daytime — leisure mode
    if (isWeekend && hour >= 9 && hour < 18) {
      return '''current block: ${_hourLabel(hour)} on ${dayOfWeek.toUpperCase()} — WEEKEND DAYTIME (leisure ok)
OK: going out, social plans, activities, errands, food, exploring. Treat as free time.
NOT OK: nightlife (that's evening), heavy wind-down (that's night).''';
    }

    // Prime leisure / social (any day)
    if (hour >= 18 && hour < 22) {
      return 'current block: 6pm–10pm — prime leisure time. social, going out, active, food, plans — all valid.';
    }

    // Late night wind-down (any day)
    return '''current block: 10pm–12am — winding down
low-key, home-leaning. light social ok. do NOT suggest starting big plans or late-night heavy commitments.
nudging toward wrapping up the evening.''';
  }

  static bool _isOutdoorBlocked(int hour, String dayOfWeek, String? weather) {
    if (hour >= 0 && hour < 5) return true; // deep night
    if (weather == null) return false;
    return weather == 'rainy' ||
        weather == 'snowy' ||
        weather == 'stormy' ||
        weather == 'foggy';
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
