import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/trombl_theme.dart';
import '../../decide/providers/decide_providers.dart';
import '../../home/providers/home_providers.dart';
import '../../profile/presentation/profile_screen.dart' show tromsReadDataProvider;
import '../../vibe/providers/session_providers.dart';
import '../domain/checkin_item.dart';
import '../providers/checkin_providers.dart';

/// Shows the "did u actually do it?" bottom sheet for a single open-loop
/// task — a menu Pick or an accepted AiPick, whichever the resume check
/// found. Triggered once per task on app resume — see [TaskWrapupController].
Future<void> showTaskWrapupSheet(
  BuildContext context,
  CheckinItem task, {
  required String vibe,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => TaskWrapupSheet(task: task, vibe: vibe),
  );
}

class TaskWrapupSheet extends ConsumerWidget {
  const TaskWrapupSheet({super.key, required this.task, required this.vibe});
  final CheckinItem task;
  final String vibe;

  Future<void> _answer(BuildContext context, WidgetRef ref, bool done) async {
    HapticFeedback.mediumImpact();

    // Same dispatch as CheckinNotifier.toggle — one place decides which
    // repo owns which item type.
    switch (task) {
      case CheckinPickItem():
        await ref.read(sessionRepositoryProvider).setPickDone(task.id, done);
      case CheckinAiPickItem():
        await ref.read(decideRepositoryProvider).markDone(task.id, done: done);
    }

    // Hook for future AI summary generation — follow the same pattern as
    // CheckinNotifier._generateMemoryNode (SystemPrompts + llmProvider +
    // sessionRepository.saveMemoryNode), keyed off `task` + `done` here.

    ref.invalidate(homeGreetingProvider);
    ref.invalidate(tromsReadDataProvider);
    ref.invalidate(checkinPicksProvider);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = TromblColors.accentFor(vibe);

    return Container(
      decoration: const BoxDecoration(
        color: TromblColors.cardLit,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).padding.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'sooo... did u actually ${task.label.toLowerCase()}? 👀',
            style: const TextStyle(
              fontFamily: TromblText.serif,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: TromblColors.text,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'main character moment or nah?',
            style: TextStyle(color: TromblColors.textSub, fontSize: 13),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _AnswerButton(
                  label: 'yes, task secured ✨',
                  accent: accent,
                  filled: true,
                  onTap: () => _answer(context, ref, true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AnswerButton(
                  label: 'nope',
                  accent: TromblColors.textMuted,
                  filled: false,
                  onTap: () => _answer(context, ref, false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.accent,
    required this.filled,
    required this.onTap,
  });
  final String label;
  final Color accent;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: filled ? accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled ? accent.withValues(alpha: 0.3) : TromblColors.border,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: filled ? accent : TromblColors.textSub,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            fontFamily: TromblText.sans,
          ),
        ),
      ),
    );
  }
}
