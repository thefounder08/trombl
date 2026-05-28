import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ai/models/llm_message.dart';
import '../../../core/ai/system_prompts.dart';
import '../../../core/providers.dart';
import '../../../core/theme/trombl_theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/result.dart';
import '../../vibe/providers/session_providers.dart';
import '../../plans/providers/plan_providers.dart';

final _currentProfileProvider = FutureProvider.autoDispose<Profile?>((ref) {
  return ref.watch(sessionRepositoryProvider).getProfile();
});

final _weeklyReadProvider = FutureProvider.autoDispose<String>((ref) async {
  final sessions = await ref.watch(_recentSessionsProvider.future);
  if (sessions.isEmpty) return '';

  final picks = await ref
      .read(sessionRepositoryProvider)
      .picksForSessions(sessions.map((s) => s.id).toList());

  final fomo = sessions.where((s) => s.vibe == 'fomo').length;
  final jomo = sessions.length - fomo;

  final tagCounts = <String, int>{};
  for (final p in picks) {
    tagCounts[p.tag] = (tagCounts[p.tag] ?? 0) + 1;
  }
  final topTags = (tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
      .take(3)
      .map((e) => e.key.replaceAll('-', ' '))
      .join(', ');

  final doneRate = picks.isEmpty
      ? 0
      : (picks.where((p) => p.done).length * 100 ~/ picks.length);

  final stats =
      '${sessions.length} sessions: $fomo fomo, $jomo jomo. '
      'most into: ${topTags.isEmpty ? "nothing yet" : topTags}. '
      'did ${doneRate}% of things picked.';

  final Result<String> result = await ref.read(llmProvider).generate(
        LlmRequest(
          system: SystemPrompts.weeklyRead(stats),
          prompt: stats,
        ),
      );
  return switch (result) {
    Success(:final data) => data,
    Failure(:final error) => error,
  };
});

final _recentSessionsProvider = FutureProvider.autoDispose<List<Session>>((ref) async {
  return ref.watch(sessionRepositoryProvider).recentSessions();
});

void _showEditName(BuildContext context, WidgetRef ref, Profile? profile) {
  final ctrl = TextEditingController(text: profile?.displayName ?? '');
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: TromblColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('what should trom call you?',
                style: TextStyle(
                    fontFamily: TromblText.serif,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: TromblColors.text)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: TromblColors.text, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'your name',
                hintStyle:
                    const TextStyle(color: TromblColors.textMuted),
                filled: true,
                fillColor: TromblColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () async {
                final name = ctrl.text.trim();
                if (name.isEmpty) return;
                await ref
                    .read(sessionRepositoryProvider)
                    .updateProfile(displayName: name);
                ref.invalidate(_currentProfileProvider);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: TromblColors.jomo,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('save →',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Color(0xFF0B0B0D),
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeklyRead = ref.watch(_weeklyReadProvider);
    final myPlans = ref.watch(myPlansProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => context.go('/menu'),
                    child: const Text('← menu',
                        style: TextStyle(color: TromblColors.textSub)),
                  ),
                  ref.watch(_currentProfileProvider).maybeWhen(
                        data: (profile) => GestureDetector(
                          onTap: () => _showEditName(context, ref, profile),
                          child: Text(
                            profile?.displayName ??
                                (profile?.handle != null
                                    ? '@${profile!.handle}'
                                    : 'set name →'),
                            style: const TextStyle(
                                color: TromblColors.textMuted, fontSize: 12),
                          ),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                ],
              ),
              const SizedBox(height: 18),
              const Text('TROM\'S READ ON YOU',
                  style: TextStyle(
                      color: TromblColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              weeklyRead.when(
                loading: () => const _TromTyping(),
                error: (_, __) => const Text(
                  "trom's still figuring u out.\npick a few things and patterns show up here.",
                  style: TextStyle(
                      fontFamily: TromblText.serif,
                      fontSize: 22,
                      color: TromblColors.text,
                      height: 1.25),
                ),
                data: (text) => text.isEmpty
                    ? const Text(
                        "trom's still figuring u out.\npick a few things and patterns show up here.",
                        style: TextStyle(
                            fontFamily: TromblText.serif,
                            fontSize: 22,
                            color: TromblColors.text,
                            height: 1.25),
                      )
                    : Text(
                        text,
                        style: const TextStyle(
                            fontFamily: TromblText.serif,
                            fontSize: 22,
                            color: TromblColors.text,
                            height: 1.25),
                      ),
              ),
              const SizedBox(height: 32),
              // Plans section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('MY PLANS',
                      style: TextStyle(
                          color: TromblColors.textMuted,
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700)),
                  GestureDetector(
                    onTap: () => context.push('/join-plan'),
                    child: const Text('join a plan →',
                        style: TextStyle(
                            color: TromblColors.textMuted, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              myPlans.when(
                loading: () => const Text('loading...',
                    style: TextStyle(
                        color: TromblColors.textMuted, fontSize: 13)),
                error: (_, __) => const SizedBox.shrink(),
                data: (plans) => plans.isEmpty
                    ? const Text(
                        'no plans yet. make one from the response screen.',
                        style: TextStyle(
                            color: TromblColors.textMuted, fontSize: 13),
                      )
                    : Column(
                        children: plans
                            .take(5)
                            .map((p) => _PlanRow(plan: p))
                            .toList(),
                      ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  await ref.read(supabaseProvider).auth.signOut();
                  ref.read(activeSessionProvider.notifier).clear();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('start over',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: TromblColors.textSub)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.plan});
  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final accent = TromblColors.accentFor(plan.vibe);
    return GestureDetector(
      onTap: () => context.push('/plan/${plan.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: TromblColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(plan.vibe == 'fomo' ? '⚡' : '🛌',
                style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                plan.title,
                style: const TextStyle(
                    color: TromblColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('→',
                style: TextStyle(color: accent, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _TromTyping extends StatefulWidget {
  const _TromTyping();

  @override
  State<_TromTyping> createState() => _TromTypingState();
}

class _TromTypingState extends State<_TromTyping>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: const Text(
          'trom is reading ur patterns...',
          style: TextStyle(
            fontFamily: TromblText.serif,
            fontSize: 22,
            color: TromblColors.textMuted,
            height: 1.25,
          ),
        ),
      ),
    );
  }
}
