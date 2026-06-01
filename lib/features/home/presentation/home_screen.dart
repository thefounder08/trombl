import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/trombl_theme.dart';
import '../../../shared/models/models.dart';
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

              // ── Zone 2: Decide hero ──────────────────────────────────────────
              TextField(
                controller: _moodCtrl,
                style: const TextStyle(
                    color: TromblColors.textSub,
                    fontSize: 14,
                    fontFamily: TromblText.sans),
                maxLines: 1,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _decide(),
                decoration: InputDecoration(
                  hintText: 'tell trom ur mood... or just tap ↓',
                  hintStyle: const TextStyle(
                      color: TromblColors.textMuted,
                      fontSize: 13,
                      fontFamily: TromblText.sans),
                  filled: true,
                  fillColor: TromblColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                ),
              ),
              const SizedBox(height: 12),

              // Hero: just decide for me ✨
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
              const SizedBox(height: 10),

              // Secondary: let me browse
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.go('/menu');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: TromblColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: TromblColors.border),
                  ),
                  child: const Text(
                    'let me browse',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: TromblColors.textSub,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
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
                continuity: greetingAsync.value != null
                    ? buildContinuity(greetingAsync.value!)
                    : null,
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
    required this.continuity,
  });
  final AsyncValue<List<Plan>> myPlans;
  final String? uid;
  final String? continuity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Plans
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

        // Continuity line
        if (continuity != null) ...[
          Text(
            continuity!,
            style: const TextStyle(
              color: TromblColors.textMuted,
              fontSize: 13,
              fontFamily: TromblText.sans,
            ),
          ),
          const SizedBox(height: 16),
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
