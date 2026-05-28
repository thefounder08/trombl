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

final _memoryNodesProvider = FutureProvider.autoDispose<List<MemoryNode>>((ref) {
  return ref.watch(sessionRepositoryProvider).recentMemoryNodes(limit: 4);
});

final _recentWrappedProvider = FutureProvider.autoDispose<List<Session>>((ref) async {
  final all = await ref.watch(_recentSessionsProvider.future);
  return all.where((s) => s.wrappedAt != null).take(3).toList();
});

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

void _showEditProfile(BuildContext context, WidgetRef ref, Profile? profile) {
  final nameCtrl = TextEditingController(text: profile?.displayName ?? '');
  final handleCtrl = TextEditingController(
      text: profile?.handle != null ? '@${profile!.handle}' : '');
  final cityCtrl = TextEditingController(text: profile?.city ?? '');

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
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
              const Text('your profile',
                  style: TextStyle(
                      fontFamily: TromblText.serif,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: TromblColors.text)),
              const SizedBox(height: 18),
              _ProfileField(ctrl: nameCtrl, hint: 'your name', label: 'NAME'),
              const SizedBox(height: 10),
              _ProfileField(
                  ctrl: handleCtrl, hint: '@handle', label: 'HANDLE'),
              const SizedBox(height: 10),
              _ProfileField(ctrl: cityCtrl, hint: 'your city', label: 'CITY'),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () async {
                  final name = nameCtrl.text.trim();
                  final rawHandle = handleCtrl.text.trim();
                  final handle = rawHandle.startsWith('@')
                      ? rawHandle.substring(1)
                      : rawHandle;
                  final city = cityCtrl.text.trim();
                  await ref.read(sessionRepositoryProvider).updateProfile(
                        displayName: name.isNotEmpty ? name : null,
                        handle: handle.isNotEmpty ? handle : null,
                        city: city.isNotEmpty ? city : null,
                      );
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
    ),
  );
}

class _ProfileField extends StatelessWidget {
  const _ProfileField(
      {required this.ctrl, required this.hint, required this.label});
  final TextEditingController ctrl;
  final String hint;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: TromblColors.textMuted,
                fontSize: 9,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: const TextStyle(color: TromblColors.text, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: TromblColors.textMuted),
            filled: true,
            fillColor: TromblColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeklyRead = ref.watch(_weeklyReadProvider);
    final myPlans = ref.watch(myPlansProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => context.go('/menu'),
                          child: const Text('← menu',
                              style: TextStyle(
                                  color: TromblColors.textSub)),
                        ),
                        ref.watch(_currentProfileProvider).maybeWhen(
                          data: (profile) => GestureDetector(
                            onTap: () =>
                                _showEditProfile(context, ref, profile),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  profile?.displayName ??
                                      (profile?.handle != null
                                          ? '@${profile!.handle}'
                                          : 'set name →'),
                                  style: const TextStyle(
                                      color: TromblColors.textMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                                if (profile?.city != null)
                                  Text(
                                    profile!.city!,
                                    style: const TextStyle(
                                        color: TromblColors.textMuted,
                                        fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Trom's weekly read
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
                    // Memory nodes
                    _MemorySection(),
                    const SizedBox(height: 28),
                    // Past days
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('PAST DAYS',
                            style: TextStyle(
                                color: TromblColors.textMuted,
                                fontSize: 10,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w700)),
                        GestureDetector(
                          onTap: () => context.push('/history'),
                          child: const Text('see all →',
                              style: TextStyle(
                                  color: TromblColors.textMuted,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _RecentDaysSummary(),
                    const SizedBox(height: 28),
                    // My plans
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
                                  color: TromblColors.textMuted,
                                  fontSize: 12)),
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
                                  color: TromblColors.textMuted,
                                  fontSize: 13),
                            )
                          : Column(
                              children: plans
                                  .take(5)
                                  .map((p) => _PlanRow(plan: p))
                                  .toList(),
                            ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            // Pinned sign-out
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

class _RecentDaysSummary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_recentWrappedProvider).when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (sessions) {
        if (sessions.isEmpty) {
          return const Text(
            'wrap ur first day to see it here.',
            style: TextStyle(color: TromblColors.textMuted, fontSize: 13),
          );
        }
        return Row(
          children: sessions.map((s) {
            final accent = TromblColors.accentFor(s.vibe);
            final d = s.startedAt;
            final label = d != null ? _dayLabel(d) : '?';
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: TromblColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.2)),
                ),
                child: Text(
                  '${s.vibe == 'fomo' ? '⚡' : '🛌'} $label',
                  style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    return '$diff days ago';
  }
}

class _MemorySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(_memoryNodesProvider);
    return nodes.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 28),
            const Text('TROM REMEMBERS',
                style: TextStyle(
                    color: TromblColors.textMuted,
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...list.map((node) => _MemoryChip(content: node.content)),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _MemoryChip extends StatelessWidget {
  const _MemoryChip({required this.content});
  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TromblColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: TromblColors.jomo.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💭 ',
              style: TextStyle(fontSize: 13)),
          Expanded(
            child: Text(
              content,
              style: const TextStyle(
                color: TromblColors.textSub,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        ],
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
