import 'package:flutter/foundation.dart';

import '../../../core/engine/context/context_models.dart';
import '../../decide/domain/ai_pick_model.dart';
import 'dynamic_menu.dart';

/// Builds the AI prompt for a full category-menu generation.
/// Single call → structured JSON → 4 categories × 4 options + new_drop.
///
/// Human-rhythm rules apply identically to single-pick generation —
/// the same time/day constraints that govern decide-for-me govern the menu.
/// Mood overrides rhythm exactly as in the single-pick engine.
abstract final class MenuPromptBuilder {
  static const _system =
      'You are trom. Return ONLY a valid JSON object. '
      'No markdown, no text before or after it, nothing else.';

  static ({String system, String prompt}) build({
    required String vibe,
    required int hour,
    required String dayOfWeek,
    required List<AiPick> recentAccepted,
    String? moodText,
    ContextSnapshot? context,
  }) {
    final bucket = TimeBucket.fromHour(hour).label;
    final isWeekend = dayOfWeek == 'sat' || dayOfWeek == 'sun';
    final dayTypeLabel = isWeekend ? 'weekend' : 'weekday';

    final historyLine = recentAccepted.isEmpty
        ? 'none'
        : recentAccepted.take(4).map((p) => p.pickText).join(', ');

    // Derive human rhythm directive from context if available,
    // otherwise use the inline logic below.
    final rhythmDirective = context?.rhythm.directive ??
        _rhythmDirective(hour, dayOfWeek, isWeekend);

    final buf = StringBuffer();

    // ── BEFORE logging point ────────────────────────────────────────────────
    final beforeMood = buf.toString();

    // Mood override — always first, always strongest signal
    if (moodText != null && moodText.isNotEmpty) {
      buf.writeln('⚠️ MOOD OVERRIDE — HIGHEST PRIORITY:');
      buf.writeln('The user said: "$moodText"');
      buf.writeln('Respond to this SPECIFICALLY. Generate categories '
          'directly relevant to "$moodText".');
      buf.writeln('If mood implies work/focus → work-aware categories.');
      buf.writeln('If mood implies social/bored → social-exploration categories.');
      buf.writeln();
    }

    buf.writeln('vibe: $vibe');
    buf.writeln('time: $dayOfWeek $bucket ($dayTypeLabel)');
    buf.writeln('recent picks (personalisation): $historyLine');
    buf.writeln();

    // Human-rhythm directive
    buf.writeln('[HUMAN RHYTHM — obey unless mood above says otherwise]');
    buf.writeln(rhythmDirective);
    buf.writeln();

    buf.writeln('Generate a browse menu. Return exactly this JSON shape:');
    buf.writeln('{"categories":[{"emoji":"...","title":"...","sub":"...","options":[{"label":"...","tag":"..."}]}],"new_drop":{"emoji":"...","title":"...","sub":"...","options":[{"label":"...","tag":"..."}]}}');
    buf.writeln();
    buf.writeln('Rules:');
    buf.writeln('- exactly 4 categories, exactly 4 options each');
    buf.writeln('- exactly 1 new_drop, exactly 4 options');
    buf.writeln('- option tags: solo | squad | discover | "order in" | rest | content');
    buf.writeln('- all text lowercase, trom voice (punchy, honest, warm)');
    buf.writeln('- options must fit the human rhythm rules above');
    buf.writeln('- no venue names, no markdown');
    buf.writeln('- VARY categories — do not repeat the same category patterns every time');
    if (moodText != null && moodText.isNotEmpty) {
      buf.writeln('- word "$moodText" must be reflected in at least one category title or subtitle');
    }

    final finalPrompt = buf.toString().trim();

    // ── Prompt logging (BEFORE/AFTER) ───────────────────────────────────────
    debugPrint('[MenuPrompt] ═══════════════════════════════');
    debugPrint('[MenuPrompt] vibe=$vibe  bucket=$bucket  day=$dayOfWeek  mood=$moodText');
    debugPrint('[MenuPrompt] BEFORE mood injection:\n$beforeMood');
    debugPrint('[MenuPrompt] AFTER (full prompt):\n$finalPrompt');
    debugPrint('[MenuPrompt] chars=${finalPrompt.length}');
    debugPrint('[MenuPrompt] ═══════════════════════════════');

    return (system: _system, prompt: finalPrompt);
  }

  // ─── Human rhythm directive (inline fallback when no ContextSnapshot) ─────

  static String _rhythmDirective(int hour, String dayOfWeek, bool isWeekend) {
    // Deep night
    if (hour >= 0 && hour < 5) {
      return 'DEEP NIGHT (12am-5am): only sleep/wind-down categories. '
          'No going-out, no social plans, no energy activities.';
    }
    // Early morning
    if (hour >= 5 && hour < 9) {
      return 'EARLY MORNING (5-9am): gentle wake-up categories. '
          'Morning routine, breakfast, movement, easing in. No nightlife.';
    }
    // Work morning — weekday
    if (!isWeekend && hour >= 9 && hour < 12) {
      return 'WORK MORNING — weekday 9-12am: work-compatible categories. '
          'Focus, proper break, coffee, hydration, planning. '
          'NO leisure/going-out/social-plans. '
          'If mood says "day off" → ignore and use leisure categories.';
    }
    // Work afternoon — weekday
    if (!isWeekend && hour >= 12 && hour < 18) {
      return 'WORK AFTERNOON — weekday 12-6pm: lunch + recharge categories. '
          'Lunch options, 20-min walk, focus sprint, coffee, task finish. '
          'NO bars/clubs/multi-hour outings. '
          'If mood says "day off" → switch to full leisure categories.';
    }
    // Weekend daytime
    if (isWeekend && hour >= 9 && hour < 18) {
      return 'WEEKEND DAYTIME: full leisure mode. '
          'Outings, cafes, events, friends, activities all valid. '
          'Saturday 2pm ≠ Tuesday 2pm — be adventurous.';
    }
    // Prime time
    if (hour >= 18 && hour < 22) {
      return 'PRIME TIME (6-10pm): social + leisure peak. '
          'Going out, events, dinner, entertainment, hobbies all valid. '
          'fomo → bold/social. jomo → home comforts, ordering in.';
    }
    // Wind down
    return 'WIND DOWN (10pm-12am): low-key categories only. '
        'Home entertainment, ordering in, reading, light social. '
        'No starting big plans.';
  }
}
