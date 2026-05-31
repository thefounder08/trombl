import '../data/decide_repository.dart';
import 'ai_pick_model.dart';

enum _Depth { thin, some, rich }

/// Builds the LLM prompt for a pick request. The prompt scales with how much
/// history exists — see Scenarios 3, 4, 7, 8, 9 in the feature spec.
abstract final class PickPromptBuilder {
  /// Returns (system, userPrompt) to pass to LlmRequest.
  static ({String system, String userPrompt}) build({
    required String vibe,
    required int hour,
    required String dayOfWeek,
    String? city,
    required int rerollCount,
    required DecideContext ctx,
    required List<String> inSessionRejects, // picks rerolled this session
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
      ),
    );
  }

  static const _system = '''
you are trom. pick ONE thing for the user to do right now.
rules:
- respond with ONLY a valid JSON object. nothing before it. nothing after it.
- all string values are lowercase
- no markdown, no bullet points inside strings
- no specific venue names (say "closest bar on maps" not a real bar name)
- pick something they can do alone without others needing to reply
- trom voice: short, punchy, honest, warm
- never hedge ("maybe", "you might like") — be confident

respond exactly this shape:
{"pick":"<activity, 6 words max>","reason":"<why right now, 10 words max, trom voice>","tag":"<discover|squad|order in|rest|content|solo>"}

tag guide:
- discover: find a place/event via maps or booking
- squad: text or call someone
- order in: food or delivery app
- rest: quiet down, dnd, recharge, no-screen time
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
  }) {
    final buf = StringBuffer();

    buf.writeln('vibe: $vibe');
    buf.writeln('time: $dayOfWeek, ${_hourLabel(hour)}');
    buf.writeln('city: ${city ?? "unknown"}');

    // Time constraint (Scenario 3)
    final constraint = _timeConstraint(hour, vibe);
    if (constraint.isNotEmpty) buf.writeln('constraint: $constraint');

    // Reroll context (Scenario 1)
    if (rerollCount == 1) {
      buf.writeln('note: second pick requested — vary from the first.');
    } else if (rerollCount >= 2) {
      buf.writeln(
          'note: they have rerolled $rerollCount times. acknowledge in reason with "ok not feeling it —"');
    }

    // In-session rejects for anti-repetition (Scenario 4)
    if (inSessionRejects.isNotEmpty) {
      buf.writeln('avoid (already rerolled this session): ${inSessionRejects.join(", ")}');
    }

    switch (depth) {
      case _Depth.thin:
        buf.writeln('history: thin (${sessionCount == 0 ? "first ever session" : "$sessionCount sessions"})');
        if (sessionCount == 0) {
          // Scenario 9 — honest cold start
          buf.writeln(
              'cold start: start the reason with "we just met so i\'m guessing —"');
        }

      case _Depth.some:
        final pattern = _patternSummary(recentPicks);
        if (pattern.isNotEmpty) buf.writeln('pattern: $pattern');
        buf.writeln('note: reference the pattern lightly in the reason if relevant.');

      case _Depth.rich:
        final pattern = _patternSummary(recentPicks);
        if (pattern.isNotEmpty) buf.writeln('pattern: $pattern');
        buf.writeln(
            'note: trom knows this person — can predict and reference their habits.');
    }

    buf.writeln('\npick something specific and actionable right now.');
    return buf.toString().trim();
  }

  static String _timeConstraint(int hour, String vibe) {
    if (hour >= 23 || hour < 5) {
      return 'late night — most things are closed. only solo or home-based picks.';
    }
    if (hour < 12) {
      return 'morning — no nightlife, no bars. brunch, walk, daytime only.';
    }
    if (hour >= 21) {
      return 'late evening — things winding down. no new big plans.';
    }
    return '';
  }

  static String _hourLabel(int hour) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final amPm = hour < 12 ? 'am' : 'pm';
    return '$h$amPm';
  }

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
