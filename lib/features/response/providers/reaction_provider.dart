import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/models/llm_message.dart';
import '../../../core/ai/system_prompts.dart';
import '../../../core/providers.dart';
import '../../../shared/result.dart';

typedef ReactionArgs = ({String vibe, String optionLabel});

/// Trom's reaction + clocked observation for the response screen.
/// Single AI call returning both fields. NEVER throws — Layer 3 static
/// fallback is served silently on any failure.
typedef ReactionData = ({String reaction, String clocked});

final reactionProvider = FutureProvider.autoDispose
    .family<ReactionData, ReactionArgs>((ref, args) async {
  final llm = ref.watch(llmProvider);
  final usage = ref.read(aiUsageServiceProvider);
  final system = SystemPrompts.reactionCombined(args.vibe, args.optionLabel);

  final start = DateTime.now();
  final result = await llm.generate(
      LlmRequest(system: system, prompt: args.optionLabel));
  final ms = DateTime.now().difference(start).inMilliseconds;

  return switch (result) {
    Success(:final data) => () {
        usage.log(
          endpoint: 'response',
          cacheHit: false,
          fallbackLayer: 1,
          promptChars: system.length + args.optionLabel.length,
          responseChars: data.length,
          durationMs: ms,
        );
        return _parse(data, args);
      }(),
    Failure() => () {
        usage.log(
            endpoint: 'response', cacheHit: false, fallbackLayer: 3, durationMs: ms);
        return _staticFallback(args);
      }(),
  };
});

ReactionData _parse(String raw, ReactionArgs args) {
  try {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start == -1 || end <= start) return _staticFallback(args);
    final json =
        jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
    final reaction = (json['reaction'] as String? ?? '').trim();
    final clocked = (json['clocked'] as String? ?? '').trim();
    if (reaction.isEmpty) return _staticFallback(args);
    return (reaction: reaction, clocked: clocked);
  } catch (_) {
    return _staticFallback(args);
  }
}

// Warm static copy — user never sees an error.
ReactionData _staticFallback(ReactionArgs args) {
  final fomoReactions = [
    "solid pick. go do it.",
    "that's the move. don't overthink it.",
    "ur brain already knew this.",
    "good one. make it happen.",
  ];
  final jomoReactions = [
    "good call. protecting ur energy.",
    "this is exactly what u needed.",
    "jomo mode activated. no regrets.",
    "ur body said this before ur brain did.",
  ];
  final pool = args.vibe == 'fomo' ? fomoReactions : jomoReactions;
  return (reaction: pool[Random().nextInt(pool.length)], clocked: '');
}
