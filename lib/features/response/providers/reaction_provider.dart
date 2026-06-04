import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/models/llm_message.dart';
import '../../../core/ai/system_prompts.dart';
import '../../../core/providers.dart';
import '../../../shared/result.dart';

typedef ReactionArgs = ({String vibe, String optionLabel});

/// Trom's warm 2-3 line reaction to the pick. Plain text.
final reactionProvider = FutureProvider.autoDispose
    .family<String, ReactionArgs>((ref, args) async {
  final llm = ref.watch(llmProvider);
  final result = await llm.generate(LlmRequest(
    system: SystemPrompts.reaction(args.vibe, args.optionLabel),
    prompt: args.optionLabel,
  ));
  return switch (result) {
    Success(:final data) => data.trim(),
    Failure(:final error) => throw Exception(error),
  };
});

/// One-line intimate observation about why the user picked this.
/// Separate lightweight call so reaction text never blocks on it.
final tromClockedProvider = FutureProvider.autoDispose
    .family<String, ReactionArgs>((ref, args) async {
  final llm = ref.watch(llmProvider);
  final result = await llm.generate(LlmRequest(
    system: SystemPrompts.tromClocked(args.vibe, args.optionLabel),
    prompt: args.optionLabel,
  ));
  return switch (result) {
    Success(:final data) => data.trim(),
    Failure() => '',
  };
});
