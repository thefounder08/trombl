import 'package:flutter/foundation.dart';

import '../../../core/engine/context/context_models.dart';
import '../../../core/engine/context/human_rhythm_engine.dart';
import '../../decide/domain/ai_pick_model.dart';
import 'dynamic_menu.dart';

/// Builds the AI prompt for a full category-menu generation.
///
/// Architecture change: Gemini no longer generates activities from scratch.
/// It receives the Layer 1 candidate set from HumanRhythmEngine and ranks
/// them for this user, rewriting labels in trom's voice.
///
/// This is cheaper (shorter prompt), faster (no invention needed), more
/// reliable (can't suggest nightlife at 9am — candidates forbid it), and
/// still personalized via mood + history signals.
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
    final isWeekend = dayOfWeek == 'sat' || dayOfWeek == 'sun';
    final dayType =
        isWeekend ? DayType.weekend : DayType.weekday;
    final period = HumanRhythmEngine.periodFor(hour, dayType);
    final candidates = HumanRhythmEngine.candidatesFor(period, vibe);

    final bucket = TimeBucket.fromHour(hour).label;
    final historyLine = recentAccepted.isEmpty
        ? 'none'
        : recentAccepted.take(4).map((p) => p.pickText).join(', ');

    final buf = StringBuffer();

    // Mood override — always first, always strongest signal
    if (moodText != null && moodText.isNotEmpty) {
      buf.writeln('mood: "$moodText" — primary signal. respond to this specifically.');
      buf.writeln();
    }

    buf.writeln(
        'context: $dayOfWeek $bucket, ${isWeekend ? "weekend" : "weekday"}. vibe: $vibe.');
    buf.writeln('recent picks (personalisation): $historyLine');
    buf.writeln('candidates: ${candidates.join(", ")}');
    buf.writeln();
    buf.writeln(
        'rank these candidates for this user right now. pick best 4, each becomes a menu category.');
    buf.writeln(
        'also pick 1 candidate for new_drop (or a creative extension of one).');
    if (moodText != null && moodText.isNotEmpty) {
      buf.writeln(
          'mood "$moodText" must be reflected in at least one category title or subtitle.');
    }
    buf.writeln();
    buf.writeln('return exactly this JSON shape:');
    buf.writeln(
        '{"categories":[{"emoji":"...","title":"...","sub":"...","options":[{"label":"...","tag":"..."}]}],"new_drop":{"emoji":"...","title":"...","sub":"...","options":[{"label":"...","tag":"..."}]}}');
    buf.writeln();
    buf.writeln('rules:');
    buf.writeln('- exactly 4 categories, exactly 4 options each');
    buf.writeln('- exactly 1 new_drop, exactly 4 options');
    buf.writeln(
        '- option tags: solo | squad | discover | "order in" | rest | content');
    buf.writeln('- all text lowercase, trom voice (punchy, honest, warm)');
    buf.writeln('- no venue names, no markdown');

    final finalPrompt = buf.toString().trim();

    debugPrint('[MenuPrompt] vibe=$vibe  bucket=$bucket  day=$dayOfWeek  '
        'mood=$moodText  candidates=${candidates.length}');
    debugPrint('[MenuPrompt] chars=${finalPrompt.length}');

    return (system: _system, prompt: finalPrompt);
  }
}
