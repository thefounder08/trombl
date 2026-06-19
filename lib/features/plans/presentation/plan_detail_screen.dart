import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/app_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/trombl_theme.dart';
import '../../../shared/models/models.dart';
import '../../plan/domain/plan_phrasing.dart';
import '../providers/plan_providers.dart';

Future<bool> _confirmCancel(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: TromblColors.card,
          title: const Text(
            'cancel this plan?',
            style: TextStyle(
              color: TromblColors.text,
              fontFamily: TromblText.serif,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            "everyone in loses it. can't undo.",
            style: TextStyle(color: TromblColors.textSub, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('keep it',
                  style: TextStyle(color: TromblColors.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('yeah, cancel',
                  style: TextStyle(
                      color: TromblColors.textMuted,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ) ??
      false;
}

class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.planId});
  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync         = ref.watch(planDetailProvider(planId));
    final membersAsync      = ref.watch(planMembersProvider(planId));
    final myMemberAsync     = ref.watch(myMembershipProvider(planId));
    final ownerProfileAsync = ref.watch(planOwnerProfileProvider(planId));
    final rsvpState         = ref.watch(rsvpProvider(planId));
    final uid = ref.watch(supabaseProvider).auth.currentUser?.id;

    return Scaffold(
      backgroundColor: TromblColors.bg,
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

            final accent    = TromblColors.accentFor(plan.vibe);
            final isOwner   = plan.ownerId == uid;
            final timeLabel = formatStartTime(plan.startsAt);

            // Non-owner attribution
            final ownerProfile = ownerProfileAsync.value;
            final ownerDisplayName =
                ownerProfile?.displayName ??
                (ownerProfile?.handle != null
                    ? '@${ownerProfile!.handle}'
                    : null);

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Back ─────────────────────────────────────────────────
                  GestureDetector(
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go('/home'),
                    child: const Text('← back',
                        style: TextStyle(
                            color: TromblColors.textMuted, fontSize: 13)),
                  ),
                  const SizedBox(height: 20),

                  // ── Non-owner attribution ─────────────────────────────────
                  if (!isOwner) ...[
                    Text(
                      ownerDisplayName != null
                          ? "$ownerDisplayName's plan"
                          : 'a plan',
                      style: const TextStyle(
                        fontFamily: TromblText.sans,
                        color: TromblColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ── Vibe + time ───────────────────────────────────────────
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        plan.vibe == 'fomo' ? '⚡ fomo' : '🛌 jomo',
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      if (timeLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: TromblColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: TromblColors.border),
                          ),
                          child: Text(
                            '📍 $timeLabel',
                            style: const TextStyle(
                              fontFamily: TromblText.sans,
                              color: TromblColors.textSub,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // ── Title + detail ────────────────────────────────────────
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
                  const SizedBox(height: 20),

                  // ── Non-owner RSVP ────────────────────────────────────────
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

                  // ── Body: owner vs joiner ─────────────────────────────────
                  Expanded(
                    child: membersAsync.when(
                      loading: () => const Center(
                        child: Text('loading...',
                            style: TextStyle(
                                color: TromblColors.textMuted, fontSize: 13)),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (members) {
                        final sorted = [...members]..sort((a, b) {
                            if (a.userId == uid) return -1;
                            if (b.userId == uid) return 1;
                            return 0;
                          });

                        final inCount    = members.where((m) => m.status == 'in').length;
                        final maybeCount = members.where((m) => m.status == 'maybe').length;
                        final outCount   = members.where((m) => m.status == 'out').length;

                        final profiles = ref.watch(memberProfilesProvider(planId)).value ?? {};

                        if (isOwner) {
                          // Owner: WHO'S IN → SHARE → cancel
                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // WHO'S IN header
                                Row(
                                  children: [
                                    const Text(
                                      "WHO'S IN",
                                      style: TextStyle(
                                        color: TromblColors.textMuted,
                                        fontSize: 10,
                                        letterSpacing: 2,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: TromblText.sans,
                                      ),
                                    ),
                                    if (members.isNotEmpty) ...[
                                      const Spacer(),
                                      Text(
                                        _statusSummary(inCount, maybeCount, outCount),
                                        style: const TextStyle(
                                          color: TromblColors.textMuted,
                                          fontSize: 11,
                                          fontFamily: TromblText.sans,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (members.isEmpty)
                                  const Text(
                                    "no one's here yet. share the link below.",
                                    style: TextStyle(
                                        color: TromblColors.textMuted,
                                        fontSize: 14),
                                  )
                                else
                                  ...sorted.map((m) => _MemberRow(
                                        member: m,
                                        profile: profiles[m.userId],
                                        isMe: m.userId == uid,
                                        isHost: m.userId == plan.ownerId,
                                      )),

                                const SizedBox(height: 28),

                                // SHARE — secondary, framed as "bring more people"
                                _ShareCodeRow(
                                  token: plan.shareToken,
                                  accent: accent,
                                ),

                                const SizedBox(height: 36),

                                // CANCEL — muted, gated, bottom
                                _CancelPlanButton(planId: planId),

                                const SizedBox(height: 8),
                              ],
                            ),
                          );
                        }

                        // Joiner: WHO'S IN list + make-your-own CTA
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  "WHO'S IN",
                                  style: TextStyle(
                                    color: TromblColors.textMuted,
                                    fontSize: 10,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: TromblText.sans,
                                  ),
                                ),
                                if (members.isNotEmpty) ...[
                                  const Spacer(),
                                  Text(
                                    _statusSummary(inCount, maybeCount, outCount),
                                    style: const TextStyle(
                                      color: TromblColors.textMuted,
                                      fontSize: 11,
                                      fontFamily: TromblText.sans,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (members.isEmpty)
                              const Text(
                                "no one's rsvp'd yet. share the link.",
                                style: TextStyle(
                                    color: TromblColors.textMuted,
                                    fontSize: 14),
                              )
                            else
                              Expanded(
                                child: ListView(
                                  children: sorted
                                      .map((m) => _MemberRow(
                                            member: m,
                                            profile: profiles[m.userId],
                                            isMe: m.userId == uid,
                                            isHost: m.userId == plan.ownerId,
                                          ))
                                      .toList(),
                                ),
                              ),
                            const SizedBox(height: 20),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                context.go('/home');
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: TromblColors.card,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                                ),
                                child: Text(
                                  'make ur own plan →',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    fontFamily: TromblText.sans,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
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

  static String _statusSummary(int inN, int maybeN, int outN) {
    final parts = <String>[];
    if (inN    > 0) parts.add('$inN in');
    if (maybeN > 0) parts.add('$maybeN maybe');
    if (outN   > 0) parts.add('$outN out');
    return parts.join(' · ');
  }
}

// ─── RSVP row ─────────────────────────────────────────────────────────────────

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
          : () {
              HapticFeedback.selectionClick();
              ref.read(rsvpProvider(planId).notifier).update(status);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Share code row ───────────────────────────────────────────────────────────

class _ShareCodeRow extends StatelessWidget {
  const _ShareCodeRow({required this.token, required this.accent});
  final String token;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BRING MORE PEOPLE',
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
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Clipboard.setData(ClipboardData(
                      text: '${AppConfig.shareBaseUrl}/p/$token'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('link copied'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: TromblColors.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${AppConfig.shareBaseUrl}/p/$token',
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                SharePlus.instance.share(ShareParams(
                  text:
                      'join my trombl plan!\n${AppConfig.shareBaseUrl}/p/$token',
                  subject: 'join my plan on trombl',
                ));
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: TromblColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('share 🔗',
                    style: TextStyle(
                        color: TromblColors.textSub,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Cancel button ────────────────────────────────────────────────────────────

class _CancelPlanButton extends ConsumerWidget {
  const _CancelPlanButton({required this.planId});
  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state   = ref.watch(cancelPlanProvider);
    final loading = state is AsyncLoading;

    return GestureDetector(
      onTap: loading
          ? null
          : () async {
              final confirmed = await _confirmCancel(context);
              if (!confirmed || !context.mounted) return;
              final err =
                  await ref.read(cancelPlanProvider.notifier).cancel(planId);
              if (!context.mounted) return;
              if (err != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err)),
                );
              } else {
                context.go('/home');
              }
            },
      child: Text(
        loading ? 'cancelling…' : 'cancel plan',
        style: const TextStyle(
          color: TromblColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─── Member row ───────────────────────────────────────────────────────────────

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isMe,
    required this.isHost,
    this.profile,
  });
  final PlanMember member;
  final Profile? profile;
  final bool isMe;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (member.status) {
      'in'    => ('🙌', TromblColors.fomo),
      'out'   => ('🙅', TromblColors.textMuted),
      _       => ('🤔', TromblColors.jomo),
    };

    final name = isMe
        ? 'you'
        : (profile?.displayName ??
            (profile?.handle != null ? '@${profile!.handle}' : null) ??
            'trombl user');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? TromblColors.cardLit : TromblColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: TromblColors.text,
                    fontSize: 14,
                    fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                    fontFamily: TromblText.sans,
                  ),
                ),
                if (isHost) ...[
                  const SizedBox(width: 6),
                  const Text('👑', style: TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
          Text('$icon  ${member.status}',
              style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}
