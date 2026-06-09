import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/providers.dart';
import '../../../core/theme/trombl_theme.dart';
import '../../../shared/models/models.dart';
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

final _recentSessionsProvider = FutureProvider.autoDispose<List<Session>>((ref) async {
  return ref.watch(sessionRepositoryProvider).recentSessions();
});

final _profileStatsProvider = FutureProvider.autoDispose<({int daysActive, int picksCompleted, List<Pick> recentWins})>((ref) async {
  final sessions = await ref.watch(_recentSessionsProvider.future);
  if (sessions.isEmpty) return (daysActive: 0, picksCompleted: 0, recentWins: <Pick>[]);
  final picks = await ref.read(sessionRepositoryProvider)
      .picksForSessions(sessions.map((s) => s.id).toList());
  final donePicks = picks.where((p) => p.done).toList();
  return (
    daysActive: sessions.where((s) => s.wrappedAt != null).length,
    picksCompleted: donePicks.length,
    recentWins: donePicks.take(3).toList(),
  );
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
              const Text('ur profile',
                  style: TextStyle(
                      fontFamily: TromblText.serif,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: TromblColors.text)),
              const SizedBox(height: 18),
              _ProfileField(ctrl: nameCtrl, hint: 'ur name', label: 'NAME'),
              const SizedBox(height: 10),
              _ProfileField(
                  ctrl: handleCtrl, hint: '@handle', label: 'HANDLE'),
              const SizedBox(height: 10),
              _ProfileField(ctrl: cityCtrl, hint: 'ur city', label: 'CITY'),
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

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _formatJoinDate(String? isoDate) {
  if (isoDate == null) return '';
  try {
    final dt = DateTime.parse(isoDate);
    const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun',
                    'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    return 'joined ${months[dt.month - 1]} ${dt.year}';
  } catch (_) {
    return '';
  }
}

// ─── Profile screen ───────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myPlans = ref.watch(myPlansProvider);
    final streak = ref.watch(streakProvider).valueOrNull ?? 0;
    final stats = ref.watch(_profileStatsProvider);
    final activeSession = ref.watch(activeSessionProvider);
    final user = ref.watch(supabaseProvider).auth.currentUser;
    final joinDate = _formatJoinDate(user?.createdAt);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Nav row ────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => context.go('/home'),
                              child: const Text('← home',
                                  style: TextStyle(
                                      color: TromblColors.textSub)),
                            ),
                            if (streak > 1) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: TromblColors.fomo.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '🔥$streak days',
                                  style: const TextStyle(
                                      color: TromblColors.fomo,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox.shrink(),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // ── Profile header ────────────────────────────────────
                    ref.watch(_currentProfileProvider).maybeWhen(
                      data: (profile) => _ProfileHeader(
                        profile: profile,
                        joinDate: joinDate,
                        onEdit: () => _showEditProfile(context, ref, profile),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 28),

                    // ── About You ─────────────────────────────────────────
                    ref.watch(_currentProfileProvider).maybeWhen(
                      data: (profile) {
                        final chips = <String>[
                          if (profile?.archetype?.isNotEmpty == true) profile!.archetype!,
                          if (profile?.scheduleType?.isNotEmpty == true) profile!.scheduleType!,
                          if (profile?.weekendPref?.isNotEmpty == true) profile!.weekendPref!,
                          ...?profile?.wantsMore.where((w) => w.isNotEmpty).map((w) => 'wants $w'),
                          ...?profile?.goals.where((g) => g.isNotEmpty),
                          if (profile?.lifestyle?.isNotEmpty == true) profile!.lifestyle!,
                        ];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('ABOUT YOU',
                                    style: TextStyle(
                                        color: TromblColors.textMuted,
                                        fontSize: 10,
                                        letterSpacing: 2,
                                        fontWeight: FontWeight.w700)),
                                GestureDetector(
                                  onTap: () => context.push('/onboarding'),
                                  child: Text(
                                    chips.isEmpty ? 'set up →' : 'retake →',
                                    style: const TextStyle(
                                        color: TromblColors.textMuted,
                                        fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (chips.isEmpty)
                              GestureDetector(
                                onTap: () => context.push('/onboarding'),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: TromblColors.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: TromblColors.jomo.withValues(alpha: 0.18)),
                                  ),
                                  child: const Text(
                                    'answer a few q\'s so trom gets u better →',
                                    style: TextStyle(
                                        color: TromblColors.textMuted,
                                        fontSize: 13,
                                        fontFamily: TromblText.sans),
                                  ),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: chips.map((c) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: TromblColors.card,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: TromblColors.jomo.withValues(alpha: 0.18)),
                                  ),
                                  child: Text(
                                    c,
                                    style: const TextStyle(
                                        color: TromblColors.jomo,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                )).toList(),
                              ),
                            const SizedBox(height: 28),
                          ],
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),

                    // ── Your stats ─────────────────────────────────────────
                    const Text('YOUR STATS · LAST 7 DAYS',
                        style: TextStyle(
                            color: TromblColors.textMuted,
                            fontSize: 10,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    stats.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (s) => _StatsRow(
                        daysActive: s.daysActive,
                        picksCompleted: s.picksCompleted,
                        plansCount: myPlans.valueOrNull?.length ?? 0,
                        streak: streak,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Recent wins ────────────────────────────────────────
                    stats.maybeWhen(
                      data: (s) {
                        if (s.recentWins.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('RECENT WINS',
                                style: TextStyle(
                                    color: TromblColors.textMuted,
                                    fontSize: 10,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            ...s.recentWins.map((p) => _WinRow(pick: p)),
                            const SizedBox(height: 28),
                          ],
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),

                    // ── Trom remembers ─────────────────────────────────────
                    _MemorySection(),

                    const SizedBox(height: 28),

                    // ── Past days ──────────────────────────────────────────
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

                    // ── My plans ───────────────────────────────────────────
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

                    // ── Wrap up your day (fallback if missed) ──────────────
                    if (activeSession != null && activeSession.wrappedAt == null) ...[
                      const SizedBox(height: 28),
                      GestureDetector(
                        onTap: () => context.push('/checkin'),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: TromblColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: TromblColors.border),
                          ),
                          child: const Row(
                            children: [
                              Text('📦', style: TextStyle(fontSize: 14)),
                              SizedBox(width: 8),
                              Text(
                                "wrap ur day →",
                                style: TextStyle(
                                  color: TromblColors.textSub,
                                  fontSize: 13,
                                  fontFamily: TromblText.sans,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Footer ────────────────────────────────────────────────────
            const _AppVersion(),
            GestureDetector(
              onTap: () async {
                await ref.read(supabaseProvider).auth.signOut();
                ref.read(activeSessionProvider.notifier).clear();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                color: Colors.transparent,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '↺  start over',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFE05252),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFFE05252),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ─── Profile header card ──────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.joinDate,
    required this.onEdit,
  });
  final Profile? profile;
  final String joinDate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final name = profile?.displayName ??
        (profile?.handle != null ? '@${profile!.handle}' : null);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: TromblColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TromblColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name ?? 'set ur name',
                      style: TextStyle(
                        fontFamily: TromblText.serif,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: name != null
                            ? TromblColors.text
                            : TromblColors.textMuted,
                        height: 1.1,
                      ),
                    ),
                    if (profile?.city != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '📍 ${profile!.city}',
                        style: const TextStyle(
                          color: TromblColors.textSub,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (joinDate.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        joinDate,
                        style: const TextStyle(
                          color: TromblColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: TromblColors.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: TromblColors.border),
                  ),
                  child: const Text(
                    'edit →',
                    style: TextStyle(
                      color: TromblColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.daysActive,
    required this.picksCompleted,
    required this.plansCount,
    required this.streak,
  });
  final int daysActive;
  final int picksCompleted;
  final int plansCount;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(value: daysActive, label: 'days'),
        const SizedBox(width: 8),
        _StatChip(value: picksCompleted, label: 'done'),
        const SizedBox(width: 8),
        if (plansCount > 0) ...[
          _StatChip(value: plansCount, label: 'plans'),
          const SizedBox(width: 8),
        ],
        if (streak > 0) _StatChip(value: streak, label: '🔥 streak'),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: TromblColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: TromblColors.border),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: TromblColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: TromblText.sans,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: TromblColors.textMuted,
              fontSize: 10,
              fontFamily: TromblText.sans,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recent win row ───────────────────────────────────────────────────────────

class _WinRow extends StatelessWidget {
  const _WinRow({required this.pick});
  final Pick pick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Text('✅', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pick.label,
              style: const TextStyle(
                color: TromblColors.textSub,
                fontSize: 13,
                fontFamily: TromblText.sans,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Plan row ─────────────────────────────────────────────────────────────────

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

// ─── Recent days summary ──────────────────────────────────────────────────────

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

// ─── Memory section ───────────────────────────────────────────────────────────

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

// ─── App version ──────────────────────────────────────────────────────────────

class _AppVersion extends StatefulWidget {
  const _AppVersion();

  @override
  State<_AppVersion> createState() => _AppVersionState();
}

class _AppVersionState extends State<_AppVersion> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = 'v${info.version}+${info.buildNumber}');
    });
  }

  @override
  Widget build(BuildContext context) => _version.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            _version,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: TromblColors.textMuted,
              fontSize: 11,
              fontFamily: TromblText.sans,
            ),
          ),
        );
}
