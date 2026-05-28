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
    await ref.read(sessionRepositoryProvider).wrapSession(session.id);
  }
}

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
