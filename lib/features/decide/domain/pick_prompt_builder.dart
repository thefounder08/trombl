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
    final rhythm = HumanRhythmEngine.derive(period);
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
      rhythmDirective: rhythm.directive,
    );

    // Log the full prompt so mood injection and time rules can be verified.
    if (moodText != null && moodText.isNotEmpty) {
      debugPrint('[PickPrompt] MOOD OVERRIDE: "$moodText" → injected ${moodCandidates.length} mood candidates: $moodCandidates');
    }
    debugPrint('[PickPrompt] period=${period.name} directive injected: ${rhythm.directive.split('\n').first}');
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
      out.addAll(['breathe for 5 mins and actually reset', 'body scan lying flat', 'put everything down for 15 mins', 'write out what\'s in ur head then close it']);
    }
    // Lonely / need company / social
    if (_any(m, ['lonely', 'alone', 'miss', 'want company', 'need someone', 'need company', 'company'])) {
      out.addAll(['text someone you miss', 'voice note a friend right now', 'make actual plans with someone this week', 'call don\'t text']);
    }
    // Want to go out / social / explore
    if (_any(m, ['go out', 'social', 'out tonight', 'people', 'see people', 'want to explore', 'explore', 'adventure', 'nightlife', 'bar', 'drinks', 'plans'])) {
      out.addAll(['text the group chat and make something happen tonight', 'find where people are tonight and just go', 'pick a direction and walk until something looks interesting', 'book something — dinner, event, whatever']);
    }
    // Need a break / pause
    if (_any(m, ['break', 'need a break', 'pause', 'step back', 'breather', 'rest', 'too much'])) {
      out.addAll(['do nothing for 20 mins, no phone', 'change ur scenery even if it\'s just another room', 'lie down with eyes closed — not sleep, just off', 'make a drink and sit with it, nothing else']);
    }
    // Low energy / sluggish
    if (_any(m, ['low energy', 'sluggish', 'unmotivated', 'no motivation', 'blah', 'meh'])) {
      out.addAll(['do one tiny thing to feel less stuck', 'get up and change location', 'put something energising on and ride it', 'eat something real if u haven\'t']);
    }
    // Just scrolling / mindless / procrastinating
    if (_any(m, ['scrolling', 'scroll', 'procrastinating', 'procrastinate', 'mindless', 'wasting time', 'doom'])) {
      out.addAll(['close all tabs and pick ONE thing', 'set a 10-min timer — do the thing u\'ve been avoiding', 'phone down, pick something physical', 'open something u actually want to do, not just default to']);
    }
    // Movement / exercise
    if (_any(m, ['move', 'exercise', 'workout', 'gym', 'run', 'walk', 'active', 'fitness', 'need to move'])) {
      out.addAll(['10-min home workout no equipment', 'walk somewhere with a destination', 'stretch properly for once', 'do something physical, even if it\'s just stairs']);
    }
    // Sad / low mood
    if (_any(m, ['sad', 'unhappy', 'miserable', 'depressed'])) {
      out.addAll(['text someone you actually trust', 'comfort show fully committed', 'short walk, no destination, no music', 'let yourself feel it — no forcing productive']);
    }
    // Quiet / calm / need space — covers "want quiet time", "calm down", "need peace"
    if (_any(m, ['quiet', 'calm', 'peace', 'peaceful', 'silence', 'decompress', 'recharge', 'space', 'slow', 'chill', 'wind down', 'wind-down', 'relax', 'need to chill'])) {
      out.addAll(['screen-free for 20, actually do it', 'ambient sounds and lie down', 'close everything and just be somewhere quiet', 'slow walk somewhere calm']);
    }

    return out;
  }

  static bool _any(String mood, List<String> keywords) =>
      keywords.any((k) => mood.contains(k));

  // ─── System prompt ────────────────────────────────────────────────────────────

  static const _system = '''
u are trom — a chaotic, warm gen z best friend who helps people decide what
to do. u have opinions. u are specific. u do NOT give generic wellness advice.

VOICE RULES (non-negotiable):
- lowercase always
- specific, not vague. "get a chai from that place near u and sit outside"
  not "get outside for 20 minutes"
- sounds like a text from a friend, not a self-improvement app
- never says: "get outside for X minutes" / "text someone you owe a reply" /
  "find a coffee spot" — these are banned, they're too generic
- one pick, confident, no hedging. commit to it.
- short reason (1 line) that sounds like ur friend clocked something about u

WHAT MAKES A GOOD PICK:
good: "order that biryani u keep saying u want, eat it in peace"
good: "put on a comfort show and fully commit to doing nothing for 2 hours"
good: "text [specific person type] and actually make a plan for this week"
good: "go for a walk but make it interesting — new route, no music"
bad: "get outside for 20 minutes" (too vague, sounds like a doctor said it)
bad: "text someone you owe a reply" (generic, anyone could say this)
bad: "find a coffee spot and go" (where?? this is not helpful)

CONTEXT RULES:
- if mood_text exists: respond to THAT specifically first and foremost
- 9am-6pm weekday: work/focus/break energy. no nightlife, no big outings
- late night (10pm+): quiet, wind-down, low effort only
- morning: routine, ease in, gentle start
- weekend: open, adventurous, social all valid

OUTPUT FORMAT (return valid JSON only, nothing before or after):
{"pick_text":"<one specific trom-voiced suggestion, under 10 words>","reason_text":"<one line why, trom voice, under 12 words>","tag":"<rest|social|food|explore|content|focus>"}

tags:
- rest: wind down, quiet time, recharge, sleep aids
- social: text or call someone, make plans
- food: order food, delivery app, cook something
- explore: find a place or event via maps or booking
- content: create or post something
- focus: do it alone, no app needed
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
    required String rhythmDirective,
  }) {
    final buf = StringBuffer();

    // ── MOOD — absolute first block, strongest signal ─────────────────────────
    if (moodText != null && moodText.isNotEmpty) {
      buf.writeln('The user said: "$moodText". Respond to THIS specifically.');
      buf.writeln('This is the most important signal — it overrides time rules.');
      if (hasMoodCandidates) {
        buf.writeln('Mood-matched candidates appear first in [CANDIDATES]. Prefer them.');
      }
      buf.writeln();
    }

    buf.writeln('[TIME]');
    buf.writeln('${dayOfWeek.toUpperCase()}, ${_hourLabel(hour)} — ${_dayType(dayOfWeek)}');
    buf.writeln(rhythmDirective);
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
      buf.writeln('[HARD REJECT — do NOT suggest anything similar to these]');
      buf.writeln(inSessionRejects.take(5).join(', '));
      buf.writeln('user already said no to all of these. different category entirely.');
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
