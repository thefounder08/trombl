import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/models/llm_message.dart';
import '../../../core/ai/system_prompts.dart';
import '../../../core/providers.dart';
import '../../../shared/result.dart';

typedef ReactionArgs = ({String vibe, String optionLabel});

final reactionProvider = FutureProvider.autoDispose
    .family<String, ReactionArgs>((ref, args) async {
  final llm = ref.watch(llmProvider);
  final result = await llm.generate(LlmRequest(
    system: SystemPrompts.reaction(args.vibe, args.optionLabel),
    prompt: args.optionLabel,
  ));
  return switch (result) {
    Success(:final data) => data,
    Failure(:final error) => throw Exception(error),
  };
});
