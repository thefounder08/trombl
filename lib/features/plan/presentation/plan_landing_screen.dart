import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/trombl_theme.dart';
import '../../../core/providers.dart';
import '../../../core/services/pending_join_service.dart';
import '../../../shared/result.dart';
import '../data/plan_repository.dart';
import '../domain/plan_phrasing.dart';
import '../providers/plan_providers.dart';
import '../../plans/providers/plan_providers.dart' show myPlansProvider;

// ─── Screen ───────────────────────────────────────────────────────────────────

class PlanLandingScreen extends ConsumerStatefulWidget {
  const PlanLandingScreen({super.key, required this.token});
  final String token;

  @override
  ConsumerState<PlanLandingScreen> createState() => _PlanLandingScreenState();
}

class _PlanLandingScreenState extends ConsumerState<PlanLandingScreen> {
  LandingData? _data;
  bool _fetching = true;
  bool _notFound = false;
  bool _responding = false;
  bool _confirmed = false;
  String? _confirmedStatus;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final result =
        await ref.read(featurePlanRepoProvider).fetchLandingData(widget.token);
    if (!mounted) return;
    setState(() {
      _fetching = false;
      switch (result) {
        case Success(:final data):
          _data = data;
        case Failure():
          _notFound = true;
      }
    });

    final data = _data;
    if (data == null || !mounted) return;

    final isLoggedIn = ref.read(currentUserProvider) != null;
    if (!isLoggedIn) return;

    // Re-opening invite after already responding → show confirmation
    // immediately. A 'pending' row means they were invited but haven't
    // actually responded yet (see the Make Plan flow's Invite Friends
    // step) — that's not a response, so fall through to the normal
    // i'm-in/can't-tonight view instead of a stale "confirmed" screen.
    final membership = await ref
        .read(featurePlanRepoProvider)
        .myMembership(data.plan.id);
    if (!mounted) return;
    if (membership != null && membership.status != 'pending') {
      setState(() {
        _confirmed = true;
        _confirmedStatus = membership.status;
      });
      return;
    }

    // Not yet a member — auto-complete any pending join intent.
    final pendingStatus = ref.read(pendingPlanStatusProvider);
    if (pendingStatus != null) {
      await _respond(pendingStatus);
    }
  }

  Future<void> _respond(String status) async {
    HapticFeedback.mediumImpact();
    final loggedIn = ref.read(currentUserProvider) != null;

    if (!loggedIn) {
      // Persist intent so it survives login, name-setup, and magic-link restart.
      ref.read(pendingPlanTokenProvider.notifier).state = widget.token;
      ref.read(pendingPlanStatusProvider.notifier).state = status;
      unawaited(PendingJoinService.save(widget.token, status));
      context.go('/login');
      return;
    }

    final plan = _data?.plan;
    if (plan == null) return;

    setState(() => _responding = true);
    final result =
        await ref.read(featurePlanRepoProvider).joinPlan(plan.id, status);
    if (!mounted) return;
    setState(() => _responding = false);

    switch (result) {
      case Success():
        ref.read(analyticsRepositoryProvider).trackPlanJoined(status: status);
        // Same gap as plan creation — Home's myPlansProvider watch survives
        // underneath this route and won't refetch on its own.
        ref.invalidate(myPlansProvider);
        // Clear pending intent — join is written.
        ref.read(pendingPlanStatusProvider.notifier).state = null;
        unawaited(PendingJoinService.clear());
        setState(() {
          _confirmed = true;
          _confirmedStatus = status;
        });
      case Failure(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.read(currentUserProvider)?.id;
    final isOwner = uid != null && _data != null && uid == _data!.plan.ownerId;
    return Scaffold(
      backgroundColor: TromblColors.bg,
      body: SafeArea(
        child: _fetching
            ? const _PulsingTrom()
            : _notFound
                ? const _NotFound()
                : _confirmed
                    ? _ConfirmedView(status: _confirmedStatus!)
                    : _PlanView(
                        data: _data!,
                        isOwner: isOwner,
                        responding: _responding,
                        onRespond: _respond,
                      ),
      ),
    );
  }
}

// ─── Loading ──────────────────────────────────────────────────────────────────

class _PulsingTrom extends StatefulWidget {
  const _PulsingTrom();

  @override
  State<_PulsingTrom> createState() => _PulsingTromState();
}

class _PulsingTromState extends State<_PulsingTrom>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: AnimatedBuilder(
          animation: _anim,
          builder: (_, _) => Opacity(
            opacity: _anim.value,
            child: const Text(
              'trom.',
              style: TextStyle(
                fontFamily: TromblText.serif,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: TromblColors.text,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      );
}

// ─── Not found ────────────────────────────────────────────────────────────────

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            "this plan's gone quiet.\nask ur friend for a fresh link.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TromblText.serif,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: TromblColors.textSub,
              height: 1.3,
            ),
          ),
        ),
      );
}

// ─── Confirmed ────────────────────────────────────────────────────────────────

class _ConfirmedView extends StatelessWidget {
  const _ConfirmedView({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final isIn = status == 'in';
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            isIn
                ? "u're in.\ntrom's got this. 🔥"
                : "trom respects it.\nnext time.",
            style: const TextStyle(
              fontFamily: TromblText.serif,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: TromblColors.text,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          // FIX 5 — viral loop: joiner → creator
          if (isIn) ...[
            GestureDetector(
              onTap: () => context.go('/vibe'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [TromblColors.fomo, TromblColors.jomo],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'wanna make ur own? →',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TromblText.sans,
                    color: Color(0xFF090909),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          GestureDetector(
            onTap: () => context.go('/home'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: TromblColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: TromblColors.border),
              ),
              child: const Text(
                'open trombl',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TromblColors.textSub,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Main plan view ───────────────────────────────────────────────────────────

class _PlanView extends StatelessWidget {
  const _PlanView({
    required this.data,
    required this.isOwner,
    required this.responding,
    required this.onRespond,
  });
  final LandingData data;
  final bool isOwner;
  final bool responding;
  final void Function(String) onRespond;

  @override
  Widget build(BuildContext context) {
    final accent   = TromblColors.accentFor(data.plan.vibe);
    final inviter  = data.ownerName ?? 'someone';
    final headline = planPhrasing(data.plan.title);
    final detail   = data.plan.detail?.trim();
    final timeLabel = formatStartTime(data.plan.startsAt);

    return Column(
      children: [
        // ── Scrollable content ──────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 44, 26, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Owner attribution — FIX 2
                if (isOwner)
                  _OwnerBadge(accent: accent)
                else
                  _InviterRow(name: inviter, vibe: data.plan.vibe),
                const SizedBox(height: 32),

                // 2. Vibe pill + optional time pill — FIX 3
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _VibePill(vibe: data.plan.vibe, accent: accent),
                    if (timeLabel != null) _TimePill(label: timeLabel),
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Headline
                Text(
                  headline,
                  style: const TextStyle(
                    fontFamily: TromblText.serif,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: TromblColors.text,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
                if (detail != null && detail.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: TromblColors.textSub,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],

                // 4. Context line
                const SizedBox(height: 22),
                const Text(
                  "trombl helps u + ur friends actually decide what to do. no more 'idk u pick.'",
                  style: TextStyle(
                    color: TromblColors.textMuted,
                    fontSize: 12,
                    height: 1.55,
                  ),
                ),

                // 5. Social proof
                if (data.memberCount > 0) ...[
                  const SizedBox(height: 22),
                  _SocialProof(
                    memberCount: data.memberCount,
                    memberInitials: data.memberInitials,
                    memberNames: data.memberNames,
                    accent: accent,
                  ),
                ],

                const SizedBox(height: 36),
              ],
            ),
          ),
        ),

        // ── Sticky CTAs ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 0),
          child: Column(
            children: [
              _CtaButton(
                label: responding ? 'one sec…' : "i'm in",
                primary: true,
                accent: accent,
                onTap: responding ? null : () => onRespond('in'),
              ),
              const SizedBox(height: 10),
              _CtaButton(
                label: responding ? 'one sec…' : "can't tonight",
                primary: false,
                accent: accent,
                onTap: responding ? null : () => onRespond('out'),
              ),
            ],
          ),
        ),

        // ── Footer ──────────────────────────────────────────────────────────
        const SizedBox(height: 14),
        const Text(
          'made with trombl · trombl.com',
          textAlign: TextAlign.center,
          style: TextStyle(color: TromblColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}

// ─── Inviter row ──────────────────────────────────────────────────────────────

class _InviterRow extends StatelessWidget {
  const _InviterRow({required this.name, required this.vibe});
  final String name;
  final String vibe;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isFomo = vibe == 'fomo';
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: isFomo
                  ? [TromblColors.fomo, const Color(0xFFE07800)]
                  : [TromblColors.jomo, const Color(0xFF8B74D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Color(0xFF0B0B0D),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: TromblText.sans,
                fontSize: 15,
                color: TromblColors.text,
                height: 1.3,
              ),
              children: [
                TextSpan(
                  text: name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(
                  text: ' wants you in',
                  style: TextStyle(
                    color: TromblColors.textSub,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Vibe pill ────────────────────────────────────────────────────────────────

class _VibePill extends StatelessWidget {
  const _VibePill({required this.vibe, required this.accent});
  final String vibe;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Text(
          vibe == 'fomo' ? '⚡ fomo' : '🛌 jomo',
          style: TextStyle(
            color: accent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      );
}

// ─── Owner badge (shown on landing when viewer IS the owner) ─────────────────

class _OwnerBadge extends StatelessWidget {
  const _OwnerBadge({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.30)),
        ),
        child: Text(
          '👑 your plan',
          style: TextStyle(
            fontFamily: TromblText.sans,
            color: accent,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

// ─── Time pill ────────────────────────────────────────────────────────────────

class _TimePill extends StatelessWidget {
  const _TimePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: TromblColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: TromblColors.border),
        ),
        child: Text(
          '📍 $label',
          style: const TextStyle(
            fontFamily: TromblText.sans,
            color: TromblColors.textSub,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

// ─── Social proof ─────────────────────────────────────────────────────────────

class _SocialProof extends StatelessWidget {
  const _SocialProof({
    required this.memberCount,
    required this.memberInitials,
    required this.memberNames,
    required this.accent,
  });
  final int memberCount;
  final List<String> memberInitials;
  final List<String> memberNames;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final String label;
    if (memberNames.isNotEmpty) {
      final rest = memberCount - 1;
      label = rest > 0
          ? '${memberNames.first} + $rest already in'
          : '${memberNames.first} already in';
    } else {
      label = '$memberCount already in';
    }

    final avatarCount = memberInitials.length.clamp(0, 4);
    final stackWidth = avatarCount > 0 ? (avatarCount * 20.0) + 8.0 : 0.0;

    return Row(
      children: [
        if (avatarCount > 0)
          SizedBox(
            height: 28,
            width: stackWidth,
            child: Stack(
              children: [
                for (var i = 0; i < avatarCount; i++)
                  Positioned(
                    left: i * 20.0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.22),
                        border: Border.all(color: TromblColors.bg, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          memberInitials[i],
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (avatarCount > 0) const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: TromblColors.textSub,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── CTA button ───────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.label,
    required this.primary,
    required this.accent,
    this.onTap,
  });
  final String label;
  final bool primary;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: onTap == null ? 0.5 : 1.0,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 17),
            decoration: BoxDecoration(
              color: primary ? accent : TromblColors.card,
              borderRadius: BorderRadius.circular(16),
              border: primary ? null : Border.all(color: TromblColors.border),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    primary ? const Color(0xFF090909) : TromblColors.textSub,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
      );
}
