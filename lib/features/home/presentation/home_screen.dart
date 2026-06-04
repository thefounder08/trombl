import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/trombl_theme.dart';
import '../../../shared/models/models.dart';
import '../../decide/domain/ai_pick_model.dart';
import '../../decide/providers/decide_providers.dart';
import '../../menu/providers/menu_providers.dart';
import '../../plans/providers/plan_providers.dart';
import '../../vibe/providers/session_providers.dart';
import '../providers/home_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _moodCtrl = TextEditingController();

  @override
  void dispose() {
    _moodCtrl.dispose();
    super.dispose();
  }

  void _decide() {
    HapticFeedback.mediumImpact();
    final mood = _moodCtrl.text.trim();
    if (mood.isNotEmpty) {
      ref.read(moodInputProvider.notifier).state = mood;
      _moodCtrl.clear();
    }
    ref.read(decideShouldAutoStartProvider.notifier).state = true;
    context.go('/decide');
  }

  // Level 1: fomo/jomo chip → category menu (not single-pick).
  // Mood from the text field is forwarded so the menu generates mood-aware categories.
  Future<void> _vibeDecide(String targetVibe) async {
    HapticFeedback.mediumImpact();
    final session = ref.read(activeSessionProvider);
    if (session == null) return;

    // Forward any typed mood to the menu provider before navigating.
    final mood = _moodCtrl.text.trim();
    if (mood.isNotEmpty) {
      ref.read(menuMoodProvider.notifier).state = mood;
      _moodCtrl.clear();
    } else {
      ref.read(menuMoodProvider.notifier).state = null;
    }

    if (session.vibe != targetVibe) {
      await ref.read(activeSessionProvider.notifier).switchVibe();
    }
    if (!mounted) return;
    context.go('/menu');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);

    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/vibe');
      });
      return const Scaffold(backgroundColor: TromblColors.bg);
    }

    final vibe = session.vibe;
    final accent = TromblColors.accentFor(vibe);
    final greetingAsync = ref.watch(homeGreetingProvider);
    final myPlans = ref.watch(myPlansProvider);
    final uid = ref.watch(supabaseProvider).auth.currentUser?.id;

    return Scaffold(
      backgroundColor: TromblColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ─────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _VibeChip(
                    vibe: vibe,
                    accent: accent,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      ref.read(activeSessionProvider.notifier).switchVibe();
                    },
                  ),
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: TromblColors.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: TromblColors.border),
                      ),
                      child: const Center(
                        child: Text('○',
                            style: TextStyle(
                                color: TromblColors.textSub, fontSize: 14)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Zone 1: Greeting ─────────────────────────────────────────────
              greetingAsync.when(
                loading: () => const SizedBox(height: 30),
                error: (_, __) => const SizedBox(height: 30),
                data: (data) => Text(
                  buildGreeting(data, vibe),
                  style: const TextStyle(
                    fontFamily: TromblText.serif,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: TromblColors.text,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // ── Zone 2: Decide hero (Level 2 — mood as primary signal) ─────
              TextField(
                controller: _moodCtrl,
                style: const TextStyle(
                    color: TromblColors.text,
                    fontSize: 15,
                    fontFamily: TromblText.sans),
                maxLines: 2,
                minLines: 1,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _decide(),
                decoration: InputDecoration(
                  hintText: "what's going on? (working, bored, tired...)",
                  hintStyle: const TextStyle(
                      color: TromblColors.textMuted,
                      fontSize: 14,
                      fontFamily: TromblText.sans),
                  filled: true,
                  fillColor: TromblColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 15),
                ),
              ),
              const SizedBox(height: 12),

              // Level 0 / Level 2: just decide (works with or without mood text).
              GestureDetector(
                onTap: _decide,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [TromblColors.fomo, TromblColors.jomo],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'just decide for me ✨',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF090909),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      fontFamily: TromblText.sans,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Level 1: fomo / jomo chips — static brand anchor, instant entry.
              _VibeChips(
                currentVibe: vibe,
                onTap: _vibeDecide,
              ),
              const SizedBox(height: 14),

              // Browse — truly secondary, text link only (never a button).
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.go('/menu');
                },
                child: const SizedBox(
                  width: double.infinity,
                  child: Text(
                    'or browse instead →',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: TromblColors.textMuted,
                      fontSize: 12,
                      fontFamily: TromblText.sans,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ── Zone 3: What's going on ──────────────────────────────────────
              _Zone3(
                myPlans: myPlans,
                uid: uid,
                greetingData: greetingAsync.value,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Vibe chip ────────────────────────────────────────────────────────────────

class _VibeChip extends StatelessWidget {
  const _VibeChip(
      {required this.vibe, required this.accent, required this.onTap});
  final String vibe;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.28), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              vibe == 'fomo' ? '⚡ fomo' : '🛌 jomo',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                fontSize: 12,
                fontFamily: TromblText.sans,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              vibe == 'fomo' ? '→ 🛌' : '→ ⚡',
              style:
                  TextStyle(color: accent.withValues(alpha: 0.45), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Zone 3 ───────────────────────────────────────────────────────────────────

class _Zone3 extends ConsumerWidget {
  const _Zone3({
    required this.myPlans,
    required this.uid,
    required this.greetingData,
  });
  final AsyncValue<List<Plan>> myPlans;
  final String? uid;
  final HomeGreetingData? greetingData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = greetingData;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Pending check-ins ────────────────────────────────────────────────
        if (data != null && data.pendingCheckins.isNotEmpty) ...[
          _CheckInSection(picks: data.pendingCheckins),
          const SizedBox(height: 28),
        ],

        // ── Plans ────────────────────────────────────────────────────────────
        myPlans.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (plans) {
            if (plans.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR PLANS',
                  style: TextStyle(
                    color: TromblColors.textMuted,
                    fontSize: 9,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: TromblText.sans,
                  ),
                ),
                const SizedBox(height: 10),
                ...plans.map((plan) => _PlanTile(
                      plan: plan,
                      isOwner: plan.ownerId == uid,
                    )),
                const SizedBox(height: 24),
              ],
            );
          },
        ),

        // ── Recent picks strip ───────────────────────────────────────────────
        if (data != null && data.recentAccepted.isNotEmpty) ...[
          _RecentStrip(picks: data.recentAccepted.take(3).toList()),
          const SizedBox(height: 20),
        ],

        // Profile teaser
        GestureDetector(
          onTap: () => context.push('/profile'),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "trom's read on u",
                style: TextStyle(
                  color: TromblColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: TromblText.sans,
                ),
              ),
              SizedBox(width: 4),
              Text(
                '→',
                style: TextStyle(
                    color: TromblColors.textMuted,
                    fontSize: 13,
                    fontFamily: TromblText.sans),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Recent picks strip ───────────────────────────────────────────────────────

class _RecentStrip extends StatelessWidget {
  const _RecentStrip({required this.picks});
  final List<AiPick> picks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'WHAT YOU\'VE BEEN UP TO',
              style: TextStyle(
                color: TromblColors.textMuted,
                fontSize: 9,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                fontFamily: TromblText.sans,
              ),
            ),
            GestureDetector(
              onTap: () => GoRouter.of(context).push('/history'),
              child: const Text(
                'see all →',
                style: TextStyle(
                  color: TromblColors.textMuted,
                  fontSize: 11,
                  fontFamily: TromblText.sans,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...picks.map((p) => _RecentPickRow(pick: p)),
      ],
    );
  }
}

class _RecentPickRow extends StatelessWidget {
  const _RecentPickRow({required this.pick});
  final AiPick pick;

  @override
  Widget build(BuildContext context) {
    final accent = TromblColors.accentFor(pick.vibe);
    final timeLabel = relativePickTime(pick.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            vibeEmoji(pick.vibe),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pick.pickText,
              style: TextStyle(
                color: accent.withValues(alpha: 0.85),
                fontSize: 13,
                fontFamily: TromblText.sans,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (timeLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              timeLabel,
              style: const TextStyle(
                color: TromblColors.textMuted,
                fontSize: 11,
                fontFamily: TromblText.sans,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Check-in section ─────────────────────────────────────────────────────────

class _CheckInSection extends ConsumerStatefulWidget {
  const _CheckInSection({required this.picks});
  final List<AiPick> picks;

  @override
  ConsumerState<_CheckInSection> createState() => _CheckInSectionState();
}

class _CheckInSectionState extends ConsumerState<_CheckInSection> {
  // IDs dismissed locally so the card vanishes instantly without a full reload.
  final Set<String> _dismissed = {};

  Future<void> _answer(AiPick pick, bool done) async {
    HapticFeedback.selectionClick();
    setState(() => _dismissed.add(pick.id));
    final repo = ref.read(decideRepositoryProvider);
    await repo.markDone(pick.id, done: done);
    // Invalidate so the provider re-fetches on next visit.
    ref.invalidate(homeGreetingProvider);
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.picks.where((p) => !_dismissed.contains(p.id)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'OPEN LOOPS',
          style: TextStyle(
            color: TromblColors.textMuted,
            fontSize: 9,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
            fontFamily: TromblText.sans,
          ),
        ),
        const SizedBox(height: 10),
        ...visible.map((p) => _CheckInCard(pick: p, onAnswer: _answer)),
      ],
    );
  }
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.pick, required this.onAnswer});
  final AiPick pick;
  final void Function(AiPick, bool) onAnswer;

  @override
  Widget build(BuildContext context) {
    final accent = TromblColors.accentFor(pick.vibe);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: TromblColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'did you actually ${pick.pickText.toLowerCase()}?',
            style: const TextStyle(
              color: TromblColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontFamily: TromblText.sans,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _AnswerBtn(
                label: 'yeah, did it',
                accent: accent,
                filled: true,
                onTap: () => onAnswer(pick, true),
              ),
              const SizedBox(width: 8),
              _AnswerBtn(
                label: 'nah',
                accent: TromblColors.textMuted,
                filled: false,
                onTap: () => onAnswer(pick, false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnswerBtn extends StatelessWidget {
  const _AnswerBtn({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accent.withValues(alpha: filled ? 0.3 : 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? accent : TromblColors.textSub,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: TromblText.sans,
          ),
        ),
      ),
    );
  }
}

// ─── Plan tile ────────────────────────────────────────────────────────────────

class _PlanTile extends ConsumerWidget {
  const _PlanTile({required this.plan, required this.isOwner});
  final Plan plan;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inCount = ref.watch(planInCountProvider(plan.id)).value;
    final accent = TromblColors.accentFor(plan.vibe);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/plan/${plan.id}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: TromblColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    style: const TextStyle(
                      color: TromblColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: TromblText.sans,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    [
                      isOwner ? 'ur plan' : 'joined',
                      if (inCount != null && inCount > 0) '$inCount in',
                    ].join(' · '),
                    style: const TextStyle(
                      color: TromblColors.textMuted,
                      fontSize: 11,
                      fontFamily: TromblText.sans,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '→',
              style: TextStyle(
                  color: accent.withValues(alpha: 0.5), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Level 1: fomo / jomo vibe chips ─────────────────────────────────────────
// Static brand anchor — instant, no AI, highlights the active vibe.

class _VibeChips extends StatelessWidget {
  const _VibeChips({required this.currentVibe, required this.onTap});
  final String currentVibe;
  final Future<void> Function(String vibe) onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip(
          emoji: '⚡',
          label: 'fomo',
          active: currentVibe == 'fomo',
          accent: TromblColors.fomo,
          onTap: () => onTap('fomo'),
        ),
        const SizedBox(width: 10),
        _Chip(
          emoji: '🛌',
          label: 'jomo',
          active: currentVibe == 'jomo',
          accent: TromblColors.jomo,
          onTap: () => onTap('jomo'),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.emoji,
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? accent.withValues(alpha: 0.12)
                : TromblColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? accent.withValues(alpha: 0.38)
                  : TromblColors.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? accent : TromblColors.textSub,
                  fontSize: 13,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w500,
                  fontFamily: TromblText.sans,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
