import '../../decide/domain/ai_pick_model.dart';
import 'dynamic_menu.dart';

/// Builds the lean AI prompt for a full menu generation in one call.
/// Single call → structured JSON → whole menu. No per-category calls.
abstract final class MenuPromptBuilder {
  static const _system =
      'you are trom. return ONLY a valid JSON object. no markdown. nothing before or after.';

  static ({String system, String prompt}) build({
    required String vibe,
    required int hour,
    required String dayOfWeek,
    required List<AiPick> recentAccepted,
  }) {
    final bucket = TimeBucket.fromHour(hour).label;

    final historyLine = recentAccepted.isEmpty
        ? 'no history'
        : recentAccepted.take(4).map((p) => p.pickText).join(', ');

    final prompt = '''
vibe: $vibe
time: $dayOfWeek $bucket
recent picks (personalization): $historyLine

return a browse menu. JSON schema (use EXACTLY this shape):
{"categories":[{"emoji":"...","title":"...","sub":"...","options":[{"label":"...","tag":"..."}]}],"new_drop":{"emoji":"...","title":"...","sub":"...","options":[{"label":"...","tag":"..."}]}}

rules:
- exactly 4 categories, exactly 4 options each
- exactly 1 new_drop, exactly 4 options
- option tags must be one of: solo squad discover "order in" rest content
- all text lowercase, option labels max 6 words
- options must be appropriate for $bucket and $vibe
- trom voice: punchy, honest — no fake-positive fluff
- no venue names, no markdown
''';

    return (system: _system, prompt: prompt.trim());
  }
}
