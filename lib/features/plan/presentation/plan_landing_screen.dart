import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/trombl_theme.dart';
import '../../../core/providers.dart';
import '../../../shared/result.dart';
import '../domain/plan_models.dart';
import '../providers/plan_providers.dart';

/// Public route `/p/:token` — shown without requiring auth.
///
/// Flow:
///  - Fetches the plan by token on mount.
///  - Shows owner name + vibe pill + plan title.
///  - "i'm in" / "can't tonight" CTAs.
///  - Logged-out: routes to /login with token stored so we return here.
///  - Logged-in: writes plan_members row + shows confirmation.
class PlanLandingScreen extends ConsumerStatefulWidget {
  const PlanLandingScreen({super.key, required this.token});
  final String token;

  @override
  ConsumerState<PlanLandingScreen> createState() => _PlanLandingScreenState();
}

class _PlanLandingScreenState extends ConsumerState<PlanLandingScreen> {
  Plan? _plan;
  bool _loading = true;
  String? _error;
  bool _confirmed = false;
  String? _confirmedStatus; // "in" | "out"

  @override
  void initState() {
    super.initState();
    _fetchPlan();
  }

  Future<void> _fetchPlan() async {
    final result =
        await ref.read(featurePlanRepoProvider).fetchByToken(widget.token);
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (result) {
        case Success(:final data):
          _plan = data;
        case Failure(:final error):
          _error = error;
      }
    });
  }

  Future<void> _respond(String status) async {
    HapticFeedback.mediumImpact();
    final loggedIn = ref.read(currentUserProvider) != null;

    if (!loggedIn) {
      // Remember which plan they were joining so login can return them here.
      ref.read(pendingPlanTokenProvider.notifier).state = widget.token;
      context.go('/login');
      return;
    }

    final plan = _plan;
    if (plan == null) return;

    setState(() => _loading = true);
    final result =
        await ref.read(featurePlanRepoProvider).joinPlan(plan.id, status);
    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case Success():
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
    return Scaffold(
      backgroundColor: TromblColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: _loading
              ? const Center(
                  child: _PulsingText('trom is loading this...'),
                )
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _error!,
                            style: const TextStyle(
                              fontFamily: TromblText.sans,
                              color: TromblColors.textSub,
                              fontSize: 15,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: const Text(
                              'open trombl →',
                              style: TextStyle(
                                fontFamily: TromblText.sans,
                                color: TromblColors.jomo,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _confirmed
                      ? _ConfirmedView(status: _confirmedStatus!)
                      : _PlanView(plan: _plan!, onRespond: _respond),
        ),
      ),
    );
  }
}

// ─── Plan view (before responding) ───────────────────────────────────────────

class _PlanView extends StatelessWidget {
  const _PlanView({required this.plan, required this.onRespond});
  final Plan plan;
  final void Function(String status) onRespond;

  @override
  Widget build(BuildContext context) {
    final accent = TromblColors.accentFor(plan.vibe);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),

        // Vibe pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          child: Text(
            plan.vibe == 'fomo' ? '⚡ fomo' : '🛌 jomo',
            style: TextStyle(
              fontFamily: TromblText.sans,
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Plan title
        Text(
          plan.title,
          style: const TextStyle(
            fontFamily: TromblText.serif,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: TromblColors.text,
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),

        if (plan.detail != null && plan.detail!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            plan.detail!,
            style: const TextStyle(
              fontFamily: TromblText.sans,
              color: TromblColors.textSub,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],

        const Spacer(),

        // CTAs
        _Cta(
          label: "i'm in",
          primary: true,
          accent: accent,
          onTap: () => onRespond('in'),
        ),
        const SizedBox(height: 12),
        _Cta(
          label: "can't tonight",
          primary: false,
          accent: accent,
          onTap: () => onRespond('out'),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

// ─── Confirmed view ───────────────────────────────────────────────────────────

class _ConfirmedView extends StatelessWidget {
  const _ConfirmedView({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final isIn = status == 'in';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        Text(
          isIn
              ? "u're in. trom's got this."
              : "maybe next time. trom filed it.",
          style: const TextStyle(
            fontFamily: TromblText.serif,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: TromblColors.text,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => context.go('/menu'),
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
                fontFamily: TromblText.sans,
                color: TromblColors.textSub,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _Cta extends StatelessWidget {
  const _Cta({
    required this.label,
    required this.primary,
    required this.accent,
    required this.onTap,
  });
  final String label;
  final bool primary;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          color: primary ? accent : TromblColors.card,
          borderRadius: BorderRadius.circular(16),
          border: primary
              ? null
              : Border.all(color: TromblColors.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TromblText.sans,
            color: primary ? const Color(0xFF090909) : TromblColors.textSub,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _PulsingText extends StatefulWidget {
  const _PulsingText(this.text);
  final String text;

  @override
  State<_PulsingText> createState() => _PulsingTextState();
}

class _PulsingTextState extends State<_PulsingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Opacity(
          opacity: _anim.value,
          child: Text(
            widget.text,
            style: const TextStyle(
              fontFamily: TromblText.sans,
              color: TromblColors.textMuted,
              fontSize: 15,
            ),
          ),
        ),
      );
}
