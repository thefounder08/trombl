import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/trombl_theme.dart';
import '../../../shared/models/models.dart';
import '../../checkin/domain/checkin_item.dart';
import '../../checkin/providers/checkin_providers.dart';
import '../../decide/domain/ai_pick_model.dart';
import '../../make_plan/presentation/make_plan_screen.dart';
import '../../menu/domain/menu_data.dart';
import '../../menu/domain/menu_models.dart';
import '../../menu/presentation/widgets/options_sheet.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../plans/providers/plan_providers.dart';
import '../../vibe/providers/session_providers.dart';
import '../providers/home_providers.dart';

/// "📦 wrap up" chip label — count of what's still unresolved today. Reads
/// checkinPicksProvider (the exact same session-scoped list Wrap Up shows)
/// rather than homeGreetingProvider's pendingCheckins, which is a 36h
/// window across *all* sessions, not just today's — using two differently
/// -scoped queries to count "the same thing" is how the badge and the
/// screen it links to end up disagreeing.
String _wrapUpLabel(List<CheckinItem>? items) {
  if (items == null) return '📦 wrap up';
  final pending = items.where((i) => !i.done).length;
  return pending > 0 ? '📦 wrap up · $pending' : '📦 wrap up';
}

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
    final checkinAsync = ref.watch(checkinPicksProvider);
    final myPlans = ref.watch(myPlansProvider);
    final uid = ref.watch(supabaseProvider).auth.currentUser?.id;

    final categories = TromblMenu.core(vibe);

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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          session.wrappedAt == null
                              ? context.push('/checkin')
                              : context.push('/day-summary/${session.id}');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: TromblColors.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: TromblColors.border),
                          ),
                          child: Text(
                            session.wrappedAt != null
                                ? '✅ wrapped'
                                : _wrapUpLabel(checkinAsync.value),
                            style: const TextStyle(
                              color: TromblColors.textSub,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              fontFamily: TromblText.sans,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const _NotificationBell(),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          ref.read(analyticsRepositoryProvider).trackProfileOpened();
                          context.push('/profile');
                        },
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
                ],
              ),

              const SizedBox(height: 32),

              // ── Zone 1: Greeting ─────────────────────────────────────────────
              greetingAsync.when(
                loading: () => const SizedBox(height: 30),
                error: (_, _) => const SizedBox(height: 30),
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

              const SizedBox(height: 28),

              // ── Zone 2a: Category grid — primary action ───────────────────────
              _CategoryGrid(categories: categories, accent: accent, vibe: vibe),

              const SizedBox(height: 20),

              // ── Zone 2b: Decide section — secondary, grouped ──────────────────
              _DecideSection(moodCtrl: _moodCtrl, onDecide: _decide),

              const SizedBox(height: 40),

              // ── Zone 3: Plans + activity ─────────────────────────────────────
              _Zone3(
                myPlans: myPlans,
                uid: uid,
                vibe: vibe,
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

// ─── Notification bell ────────────────────────────────────────────────────────

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/notifications');
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: TromblColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: TromblColors.border),
            ),
            child: const Center(
              child: Text('🔔', style: TextStyle(fontSize: 13)),
            ),
          ),
          if (unread > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 14),
                decoration: const BoxDecoration(
                  color: TromblColors.fomo,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: TromblColors.bg,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Category list (AI-driven, full-width cards like menu screen) ─────────────

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories, required this.accent, required this.vibe});
  final List<MenuCategory> categories;
  final Color accent;
  final String vibe;

  @override
  Widget build(BuildContext context) {
    final cats = categories.take(4).toList();
    return Column(
      children: List.generate(cats.length, (i) => Padding(
        padding: EdgeInsets.only(bottom: i < cats.length - 1 ? 8 : 0),
        child: _CategoryCard(cat: cats[i], accent: accent, vibe: vibe),
      )),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.cat, required this.accent, required this.vibe});
  final MenuCategory cat;
  final Color accent;
  final String vibe;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => OptionsSheet(category: cat, vibe: vibe),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: TromblColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TromblColors.border),
        ),
        child: Row(
          children: [
            // Emoji bubble — only accent touch
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(cat.emoji,
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat.title,
                    style: const TextStyle(
                      color: TromblColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: TromblText.sans,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cat.sub,
                    style: const TextStyle(
                      color: TromblColors.textMuted,
                      fontSize: 11,
                      fontFamily: TromblText.sans,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '→',
              style: TextStyle(
                  color: TromblColors.textSub, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Decide section (mood input + pill, low priority) ────────────────────────

class _DecideSection extends StatelessWidget {
  const _DecideSection(
      {required this.moodCtrl, required this.onDecide});
  final TextEditingController moodCtrl;
  final VoidCallback onDecide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: TromblColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TromblColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: moodCtrl,
            style: const TextStyle(
                color: TromblColors.text,
                fontSize: 14,
                fontFamily: TromblText.sans),
            maxLines: 2,
            minLines: 1,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onDecide(),
            decoration: const InputDecoration(
              hintText: "what's the vibe rn? (cooked, lowkey, bored af...)",
              hintStyle: TextStyle(
                  color: TromblColors.textMuted,
                  fontSize: 13,
                  fontFamily: TromblText.sans),
              filled: false,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onDecide,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: TromblColors.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: TromblColors.border),
              ),
              child: const Text(
                'just pick smth for me ✨',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TromblColors.textSub,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  fontFamily: TromblText.sans,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Zone 3 ───────────────────────────────────────────────────────────────────

class _Zone3 extends ConsumerWidget {
  const _Zone3({
    required this.myPlans,
    required this.uid,
    required this.vibe,
    required this.greetingData,
  });
  final AsyncValue<List<Plan>> myPlans;
  final String? uid;
  final String vibe;
  final HomeGreetingData? greetingData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = greetingData;
    final hasActivity = data != null &&
        (data.pendingCheckins.isNotEmpty ||
            data.recentAccepted.isNotEmpty ||
            data.todayPicks.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Plans — header always visible, this is the one entry point into
        // the Make Plan flow when there's no already-picked activity to
        // jump off of ──────────────────────────────────────────────────────
        myPlans.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (plans) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'UR PLANS',
                      style: TextStyle(
                        color: TromblColors.textMuted,
                        fontSize: 9,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: TromblText.sans,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push('/make-plan', extra: MakePlanArgs(vibe: vibe));
                      },
                      child: Text(
                        '+ new plan',
                        style: TextStyle(
                          color: TromblColors.accentFor(vibe),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: TromblText.sans,
                        ),
                      ),
                    ),
                  ],
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

        // ── Activity handle (ongoing + recent — opens sheet) ─────────────────
        if (hasActivity) ...[
          _ActivityHandle(greetingData: data),
          const SizedBox(height: 20),
        ],

        // Profile icon tap target (subtle — no label, profile has its own page)
        GestureDetector(
          onTap: () {
                          ref.read(analyticsRepositoryProvider).trackProfileOpened();
                          context.push('/profile');
                        },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "ur stats →",
                style: TextStyle(
                  color: TromblColors.textMuted,
                  fontSize: 12,
                  fontFamily: TromblText.sans,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Activity handle ─────────────────────────────────────────────────────────

class _ActivityHandle extends StatelessWidget {
  const _ActivityHandle({required this.greetingData});
  final HomeGreetingData greetingData;

  @override
  Widget build(BuildContext context) {
    final pendingCount = greetingData.pendingCheckins.length;
    final recentCount = greetingData.recentAccepted.length;
    final todayPickCount = greetingData.todayPicks.length;

    final parts = <String>[
      if (todayPickCount > 0)
        '$todayPickCount ${todayPickCount == 1 ? 'pick' : 'picks'} today',
      if (pendingCount > 0)
        '$pendingCount still pending',
      if (recentCount > 0)
        '$recentCount ai ${recentCount == 1 ? 'pick' : 'picks'} done',
    ];

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => _ActivitySheet(greetingData: greetingData),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: TromblColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TromblColors.border),
        ),
        child: Row(
          children: [
            Text(
              pendingCount > 0 ? '🔔' : '📋',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                parts.join(' · '),
                style: const TextStyle(
                  color: TromblColors.textSub,
                  fontSize: 13,
                  fontFamily: TromblText.sans,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'open →',
              style: TextStyle(
                color: TromblColors.textMuted,
                fontSize: 12,
                fontFamily: TromblText.sans,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Activity sheet (ongoing + summary) ──────────────────────────────────────

class _ActivitySheet extends ConsumerWidget {
  const _ActivitySheet({required this.greetingData});
  final HomeGreetingData greetingData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read-only here — resolving "did u actually do it" happens exclusively
    // via the resume popup / Wrap Up now, not this sheet, so there's only
    // one place that ever asks.
    final pending = greetingData.pendingCheckins;
    final recent = greetingData.recentAccepted.take(5).toList();
    final todayPicks = greetingData.todayPicks;
    final hasUnresolved = pending.isNotEmpty || todayPicks.isNotEmpty;
    final sessionVibe = ref.watch(activeSessionProvider)?.vibe ?? 'fomo';
    final sessionAccent = TromblColors.accentFor(sessionVibe);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: TromblColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: TromblColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                children: [
                  // ── Today's menu picks ──────────────────────────────────
                  const Text(
                    'PICKED TODAY',
                    style: TextStyle(
                      color: TromblColors.textMuted,
                      fontSize: 9,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: TromblText.sans,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (todayPicks.isNotEmpty) ...[
                    ...todayPicks.map((p) => _MenuPickCard(
                          pick: p,
                          accent: sessionAccent,
                        )),
                  ] else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'no picks yet today',
                        style: TextStyle(
                          color: TromblColors.textMuted,
                          fontSize: 13,
                          fontFamily: TromblText.sans,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (pending.isNotEmpty) ...[
                    const Text(
                      'LOOSE ENDS',
                      style: TextStyle(
                        color: TromblColors.textMuted,
                        fontSize: 9,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: TromblText.sans,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...pending.map((p) => _CheckInCard(pick: p)),
                    const SizedBox(height: 24),
                  ],
                  if (hasUnresolved) ...[
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        GoRouter.of(context).push('/checkin');
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: sessionAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: sessionAccent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'wrap up now →',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: sessionAccent,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            fontFamily: TromblText.sans,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (recent.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "WHAT U'VE BEEN ON",
                          style: TextStyle(
                            color: TromblColors.textMuted,
                            fontSize: 9,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                            fontFamily: TromblText.sans,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            GoRouter.of(context).push('/history');
                          },
                          child: const Text(
                            'see everything →',
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
                    ...recent.map((p) => _RecentPickRow(pick: p)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Recent pick row ──────────────────────────────────────────────────────────

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

// ─── Check-in card ────────────────────────────────────────────────────────────

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.pick});
  final AiPick pick;

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
      child: Row(
        children: [
          Expanded(
            child: Text(
              pick.pickText,
              style: const TextStyle(
                color: TromblColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: TromblText.sans,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'waiting on u 👀',
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: TromblText.sans,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Menu pick check-in card ─────────────────────────────────────────────────

class _MenuPickCard extends StatelessWidget {
  const _MenuPickCard({
    required this.pick,
    required this.accent,
  });
  final Pick pick;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: TromblColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              pick.label,
              style: const TextStyle(
                color: TromblColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: TromblText.sans,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'waiting on u 👀',
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: TromblText.sans,
            ),
          ),
        ],
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
    final myStatus = ref.watch(myMembershipProvider(plan.id)).value?.status;
    final accent = TromblColors.accentFor(plan.vibe);

    final statusLabel = isOwner
        ? 'ur plan'
        : switch (myStatus) {
            'in' => 'u\'re in',
            'maybe' => 'u said maybe',
            'out' => 'u\'re out',
            'pending' => 'u\'re invited',
            _ => 'u\'re in',
          };

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
                      statusLabel,
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
