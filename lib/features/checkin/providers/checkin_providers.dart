import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/models/llm_message.dart';
import '../../../core/ai/system_prompts.dart';
import '../../../core/providers.dart';
import '../../../shared/result.dart';
import '../../decide/providers/decide_providers.dart';
import '../../home/providers/home_providers.dart';
import '../../profile/presentation/profile_screen.dart' show tromsReadDataProvider;
import '../../vibe/providers/session_providers.dart';
import '../domain/checkin_item.dart';

final checkinPicksProvider =
    AsyncNotifierProvider.autoDispose<CheckinNotifier, List<CheckinItem>>(
        CheckinNotifier.new);

class CheckinNotifier extends AsyncNotifier<List<CheckinItem>> {
  @override
  Future<List<CheckinItem>> build() async {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return [];
    final picks = await ref
        .read(sessionRepositoryProvider)
        .picksForSessions([session.id]);
    final aiPicks =
        await ref.read(decideRepositoryProvider).aiPicksForSession(session.id);
    return [
      ...picks.map(CheckinPickItem.new),
      ...aiPicks.map(CheckinAiPickItem.new),
    ];
  }

  Future<void> toggle(String id, bool done) async {
    CheckinItem? updated;
    state = state.whenData((items) => items.map((i) {
          if (i.id != id) return i;
          final next = switch (i) {
            CheckinPickItem(:final pick) =>
              CheckinPickItem(pick.copyWith(done: done)),
            CheckinAiPickItem(:final aiPick) =>
              CheckinAiPickItem(aiPick.copyWith(done: done)),
          };
          updated = next;
          return next;
        }).toList());

    switch (updated) {
      case CheckinPickItem():
        await ref.read(sessionRepositoryProvider).setPickDone(id, done);
      case CheckinAiPickItem():
        await ref.read(decideRepositoryProvider).markDone(id, done: done);
      case null:
        return;
    }
  }

  Future<void> wrapDay() async {
    final session = ref.read(activeSessionProvider);
    if (session == null) return;

    final items = state.value ?? [];

    // Finalize any AiPick nobody ever answered (done still null) — without
    // this, wrapping the day wouldn't actually resolve it, and the resume
    // popup (TaskWrapupController) would keep asking about something the
    // day's already wrapped.
    final unanswered = items
        .whereType<CheckinAiPickItem>()
        .where((i) => i.aiPick.done == null);
    for (final i in unanswered) {
      await ref.read(decideRepositoryProvider).markDone(i.id, done: false);
    }

    final doneLabels = items.where((i) => i.done).map((i) => i.label).toList();

    // Wrap the session first
    await ref.read(sessionRepositoryProvider).wrapSession(session.id);

    // Keep Home's in-memory session (and anything reading it) from going
    // stale until the next cold-start restore.
    ref.read(activeSessionProvider.notifier).markWrapped();
    ref.invalidate(homeGreetingProvider);
    ref.invalidate(tromsReadDataProvider);

    // Hook for a future per-activity AI wrap-up summary (distinct from the
    // memory-node reaction below) — follow the same pattern as
    // _generateMemoryNode: SystemPrompts + llmProvider + a save call.
    // unawaited(_generateWrapUpSummary(session, items));

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

/// Live item count for the current session — used by menu screen.
final todayPickCountProvider = Provider.autoDispose<int>((ref) {
  final items = ref.watch(checkinPicksProvider);
  return items.maybeWhen(data: (i) => i.length, orElse: () => 0);
});

typedef DaySummaryArgs = ({
  String vibe,
  int total,
  int done,
  List<String> doneLabels,
});

/// Loads a past session + its picks from Supabase and returns DaySummaryArgs.
/// Used when navigating to /day-summary/:sessionId from a notification tap
/// (process may have been killed, so in-memory args are unavailable).
final sessionSummaryArgsProvider = FutureProvider.autoDispose
    .family<DaySummaryArgs?, String>((ref, sessionId) async {
  final repo = ref.read(sessionRepositoryProvider);
  final session = await repo.sessionById(sessionId);
  if (session == null) return null;
  final picks = await repo.picksForSessions([sessionId]);
  final done = picks.where((p) => p.done).length;
  final doneLabels = picks.where((p) => p.done).map((p) => p.label).toList();
  return (vibe: session.vibe, total: picks.length, done: done, doneLabels: doneLabels);
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
