import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/trombl_theme.dart';
import '../../../shared/models/models.dart';
import '../providers/plan_providers.dart';

class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.planId});
  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(planDetailProvider(planId));
    final membersAsync = ref.watch(planMembersProvider(planId));
    final myMemberAsync = ref.watch(myMembershipProvider(planId));
    final rsvpState = ref.watch(rsvpProvider(planId));
    final uid = ref.watch(supabaseProvider).auth.currentUser?.id;

    return Scaffold(
      body: SafeArea(
        child: planAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: TromblColors.jomo),
          ),
          error: (_, __) => const Center(
            child: Text('plan not found.',
                style: TextStyle(color: TromblColors.textMuted)),
          ),
          data: (plan) {
            if (plan == null) {
              return const Center(
                child: Text('plan not found.',
                    style: TextStyle(color: TromblColors.textMuted)),
              );
            }
            final accent = TromblColors.accentFor(plan.vibe);
            final isOwner = plan.ownerId == uid;

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go('/menu'),
                    child: const Text('← back',
                        style: TextStyle(
                            color: TromblColors.textMuted, fontSize: 13)),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    plan.vibe == 'fomo' ? '⚡ fomo' : '🛌 jomo',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    plan.title,
                    style: const TextStyle(
                      fontFamily: TromblText.serif,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: TromblColors.text,
                      height: 1.2,
                    ),
                  ),
                  if (plan.detail != null) ...[
                    const SizedBox(height: 8),
                    Text(plan.detail!,
                        style: const TextStyle(
                            color: TromblColors.textSub, fontSize: 14)),
                  ],
                  const SizedBox(height: 28),
                  // RSVP row (only for non-owners who have joined)
                  if (!isOwner) ...[
                    myMemberAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (member) => _RsvpRow(
                        currentStatus: rsvpState.value ?? member?.status,
                        planId: planId,
                        loading: rsvpState is AsyncLoading,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Members
                  const Text(
                    'WHO\'S IN',
                    style: TextStyle(
                      color: TromblColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: membersAsync.when(
                      loading: () => const Center(
                        child: Text('loading...',
                            style: TextStyle(
                                color: TromblColors.textMuted, fontSize: 13)),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (members) => members.isEmpty
                          ? const Text(
                              "no one's rsvp'd yet. share the code.",
                              style: TextStyle(
                                  color: TromblColors.textMuted, fontSize: 14),
                            )
                          : ListView(
                              children: members
                                  .map((m) => _MemberRow(member: m))
                                  .toList(),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RsvpRow extends ConsumerWidget {
  const _RsvpRow({
    required this.currentStatus,
    required this.planId,
    required this.loading,
  });
  final String? currentStatus;
  final String planId;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'YOU IN?',
          style: TextStyle(
            color: TromblColors.textMuted,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _RsvpChip(
              label: 'in 🙌',
              status: 'in',
              current: currentStatus,
              planId: planId,
              loading: loading,
            ),
            const SizedBox(width: 10),
            _RsvpChip(
              label: 'maybe 🤔',
              status: 'maybe',
              current: currentStatus,
              planId: planId,
              loading: loading,
            ),
            const SizedBox(width: 10),
            _RsvpChip(
              label: 'out 🙅',
              status: 'out',
              current: currentStatus,
              planId: planId,
              loading: loading,
            ),
          ],
        ),
      ],
    );
  }
}

class _RsvpChip extends ConsumerWidget {
  const _RsvpChip({
    required this.label,
    required this.status,
    required this.current,
    required this.planId,
    required this.loading,
  });
  final String label;
  final String status;
  final String? current;
  final String planId;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = current == status;
    return GestureDetector(
      onTap: loading
          ? null
          : () => ref.read(rsvpProvider(planId).notifier).update(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? TromblColors.jomo.withValues(alpha: 0.15)
              : TromblColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? TromblColors.jomo.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? TromblColors.jomo : TromblColors.textSub,
            fontWeight:
                isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});
  final PlanMember member;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (member.status) {
      'in' => ('🙌', TromblColors.fomo),
      'out' => ('🙅', TromblColors.textMuted),
      _ => ('🤔', TromblColors.jomo),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: TromblColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              member.userId.substring(0, 8) + '...',
              style: const TextStyle(
                  color: TromblColors.textSub, fontSize: 13),
            ),
          ),
          Text('$icon  ${member.status}',
              style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}
