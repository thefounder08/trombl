import '../data/decide_repository.dart';
import 'ai_pick_model.dart';

enum _Depth { thin, some, rich }

/// Builds the LLM prompt for a pick request using a 4-tier constraint hierarchy.
///
/// Tier order (each tier overrides/constrains everything below it):
///   1. PRIMARY DRIVERS  — mood text (most important) + exact time/day
///   2. HARD FILTERS     — time-block rules, weather, location (eliminate bad answers)
///   3. PERSONALIZERS    — history patterns, anti-repetition (enrich when available)
///   4. USER-TOLD-ONLY   — energy/budget/state only from mood text, never assumed
///
/// The model (free Gemini Flash) is a weak reasoner — constraints must be explicit
/// RULES in the prompt, not hopes the model will infer them.
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

    return (
      system: _system,
      userPrompt: _userPrompt(
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
      ),
    );
  }

  static const _system = '''
you are trom. pick ONE thing for the user to do right now.

HARD RULES — no exceptions:
- respond with ONLY a valid JSON object. nothing before it. nothing after it.
- NEVER ask a question back. mood in → decision out. this is absolute. asking a question is failure.
- ONE pick only. no lists. no alternatives. one confident thing.
- no hedging ("maybe", "you might like", "could try"). pick and commit.
- no specific venue names — give methods ("closest bar on maps", not a real bar name)
- all string values lowercase. no markdown. no bullets inside strings.
- trom voice: short, punchy, honest, warm — like a text from a real friend, not an app.
- the pick must be actionable given EVERY constraint in the user prompt.

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

    // ─── TIER 1: Primary drivers — mood + time ────────────────────────────────
    if (moodText != null && moodText.isNotEmpty) {
      buf.writeln('[MOOD — primary signal, outweighs everything else]');
      buf.writeln('the user said: "$moodText"');
      buf.writeln('respond to this specifically. it is the most important thing you know about them right now.');
      buf.writeln();
    }

    buf.writeln('[TIME]');
    buf.writeln('${dayOfWeek.toUpperCase()}, ${_hourLabel(hour)} — ${_dayType(dayOfWeek)}');
    buf.writeln();

    // ─── TIER 2: Hard filters — time block, weather, location ─────────────────
    buf.writeln('[TIME BLOCK RULES — obey absolutely, no exceptions]');
    buf.writeln(_timeBlock(hour));
    buf.writeln();

    final isOutdoorBlocked = _isOutdoorBlocked(hour, weatherCondition);
    if (isOutdoorBlocked) {
      buf.writeln('[OUTDOOR BLOCK]');
      if (weatherCondition != null &&
          weatherCondition != 'clear' &&
          weatherCondition != 'cloudy') {
        buf.writeln("weather: $weatherCondition outside — do NOT suggest outdoor activities.");
      }
      // time-of-day outdoor block is already in the time block rules above
      buf.writeln();
    }

    if (city != null && city.isNotEmpty) {
      buf.writeln('[LOCATION]');
      buf.writeln("city: $city — give a method not a venue name (e.g. \"closest open spot on maps, don't scroll past #3\")");
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
            buf.writeln('trom knows this person — can lightly reference their pattern in the reason if relevant.');
          }
          buf.writeln();
        }
    }

    if (inSessionRejects.isNotEmpty) {
      buf.writeln('[ALREADY REJECTED THIS SESSION — do not suggest these]');
      buf.writeln(inSessionRejects.join(', '));
      buf.writeln();
    }

    if (rerollCount == 1) {
      buf.writeln('note: second pick — vary meaningfully from the first.');
    } else if (rerollCount >= 2) {
      buf.writeln('note: $rerollCount rerolls — acknowledge this in reason, start with "ok not feeling it —"');
    }

    // ─── TIER 4 implicit: only what the user stated ────────────────────────────
    // (energy, budget, emotional state come ONLY from mood text above — never assumed)

    // Vibe as fallback signal — least important, only matters if mood is empty
    buf.writeln('[VIBE — fallback signal, only matters if no mood text above]');
    buf.writeln('vibe: $vibe');
    buf.writeln();

    buf.writeln('pick exactly one thing. specific. actionable. valid against every constraint above.');
    return buf.toString().trim();
  }

  // ─── Time block rules (Tier 2 hard filters) ───────────────────────────────

  static String _timeBlock(int hour) {
    if (hour >= 0 && hour < 5) {
      return '''current block: 12am–5am — DEEP NIGHT
DO NOT suggest (hard rules — no exceptions whatsoever):
  - going outside or anywhere
  - contacting people (they are asleep)
  - high-energy activities
  - errands, bars, clubs, restaurants, events
ONLY suggest:
  - wind-down techniques (dim lights, no screens, boring content)
  - sleep aids (breathing exercises, lying in dark)
  - quiet solo comfort (warm drink, quiet audio)
if they say they can't sleep or want to do something: give real wind-down advice — NEVER "go for a walk" or "text someone"''';
    }
    if (hour >= 5 && hour < 11) {
      return '''current block: 5am–11am — morning
ok: coffee, light movement, planning the day, gentle starts.
do NOT suggest: bars, clubs, nightlife, heavy late-night activities.''';
    }
    if (hour >= 11 && hour < 17) {
      return 'current block: 11am–5pm — daytime. flexible. outings, errands, productivity, food, social all valid.';
    }
    if (hour >= 17 && hour < 22) {
      return 'current block: 5pm–10pm — prime time. social, active, going out all valid.';
    }
    // 22–24
    return '''current block: 10pm–12am — winding down
low-key, home-leaning. light social ok.
do NOT suggest starting anything big or late-night heavy plans.
nudging toward wrapping up the evening.''';
  }

  static bool _isOutdoorBlocked(int hour, String? weather) {
    if (hour >= 0 && hour < 5) return true; // deep night block handles this
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
    final loved = picks
        .where((p) => p.accepted)
        .map((p) => p.pickText)
        .take(3)
        .toList();
    final skipped = picks
        .where((p) => p.rerolled)
        .map((p) => p.pickText)
        .take(3)
        .toList();
    final parts = <String>[];
    if (loved.isNotEmpty) parts.add('loved: ${loved.join(", ")}');
    if (skipped.isNotEmpty) parts.add('skipped: ${skipped.join(", ")}');
    return parts.join('. ');
  }
}
