import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/models/llm_message.dart';
import '../../../core/ai/system_prompts.dart';
import '../../../core/providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/repositories/session_repository.dart';
import '../../../shared/result.dart';
import '../../vibe/providers/session_providers.dart';

final checkinPicksProvider =
    AsyncNotifierProvider.autoDispose<CheckinNotifier, List<Pick>>(
        CheckinNotifier.new);

class CheckinNotifier extends AutoDisposeAsyncNotifier<List<Pick>> {
  @override
  Future<List<Pick>> build() async {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return [];
    return ref
        .read(sessionRepositoryProvider)
        .picksForSessions([session.id]);
  }

  Future<void> toggle(String pickId, bool done) async {
    state = state.whenData(
      (picks) => picks
          .map((p) => p.id == pickId ? p.copyWith(done: done) : p)
          .toList(),
    );
    await ref.read(sessionRepositoryProvider).setPickDone(pickId, done);
  }

  Future<void> wrapDay() async {
    final session = ref.read(activeSessionProvider);
    if (session == null) return;

    final picks = state.valueOrNull ?? [];
    final doneLabels =
        picks.where((p) => p.done).map((p) => p.label).toList();

    // Wrap the session first
    await ref.read(sessionRepositoryProvider).wrapSession(session.id);

    // Fire-and-forget: generate + store a memory node
    unawaited(_generateMemoryNode(session.vibe, doneLabels));
  }

  Future<void> _generateMemoryNode(
      String vibe, List<String> doneLabels) async {
    if (doneLabels.isEmpty) return; // nothing to remember
    try {
      final Result<String> result = await ref.read(llmProvider).generate(
            LlmRequest(
              system: SystemPrompts.memoryNode(vibe, doneLabels),
              prompt: 'write the memory note.',
            ),
          );
      if (result case Success(:final data)) {
        await ref.read(sessionRepositoryProvider).saveMemoryNode(
              type: 'observation',
              content: data.trim(),
            );
      }
    } catch (_) {}
  }
}

/// Live pick count for the current session — used by menu screen.
final todayPickCountProvider = Provider.autoDispose<int>((ref) {
  final picks = ref.watch(checkinPicksProvider);
  return picks.maybeWhen(data: (p) => p.length, orElse: () => 0);
});

typedef DaySummaryArgs = ({
  String vibe,
  int total,
  int done,
  List<String> doneLabels,
});

final daySummaryProvider = FutureProvider.autoDispose
    .family<String, DaySummaryArgs>((ref, args) async {
  final llm = ref.watch(llmProvider);
  final Result<String> result = await llm.generate(LlmRequest(
    system: SystemPrompts.daySummary(
        args.vibe, args.total, args.done, args.doneLabels),
    prompt:
        '${args.done} out of ${args.total} done on a ${args.vibe} day.',
  ));
  return switch (result) {
    Success(:final data) => data,
    Failure(:final error) => error,
  };
});
