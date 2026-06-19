import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/trombl_theme.dart';
import '../../../core/observability/analytics_service.dart';
import '../providers/session_providers.dart';
import '../../onboarding/presentation/onboarding_screen.dart' show onboardingCompletedProvider;

/// The heart of the app: fomo vs jomo. Picking creates a real session row.
class VibeScreen extends ConsumerStatefulWidget {
  const VibeScreen({super.key});

  @override
  ConsumerState<VibeScreen> createState() => _VibeScreenState();
}

class _VibeScreenState extends ConsumerState<VibeScreen> {
  // True once the user taps a vibe card — prevents the session-restore
  // listener from overriding the navigation to /decide.
  bool _picked = false;

  Future<void> _pick(String vibe) async {
    if (_picked) return;
    setState(() => _picked = true);
    HapticFeedback.heavyImpact();

    // If today's session already exists, reuse it (switch vibe if needed).
    final existing = ref.read(activeSessionProvider);
    if (existing != null) {
      if (existing.vibe != vibe) {
        await ref.read(activeSessionProvider.notifier).switchVibe();
      }
      AnalyticsService.vibePicked(vibe: vibe);
      if (mounted) context.go('/home');
      return;
    }

    final city = ref.read(cityProvider);
    final err =
        await ref.read(activeSessionProvider.notifier).start(vibe, city: city);
    if (err != null) {
      if (mounted) {
        setState(() => _picked = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
      return;
    }
    AnalyticsService.vibePicked(vibe: vibe);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    // Watch FIRST — this initialises ActiveSessionNotifier and triggers
    // _tryRestore(). Must happen before any early return or the notifier
    // never starts and sessionRestoredProvider stays false forever.
    ref.watch(activeSessionProvider);
    final restored = ref.watch(sessionRestoredProvider);

    // Redirect to onboarding if the user hasn't completed it yet.
    ref.listen(onboardingCompletedProvider, (_, next) {
      if (next.value == false && mounted) {
        context.go('/onboarding');
      }
    });
    final onboardingStatus = ref.watch(onboardingCompletedProvider);

    // Show loading while restoring session or checking onboarding status.
    if (!restored || onboardingStatus.isLoading) {
      return const Scaffold(
        backgroundColor: TromblColors.bg,
        body: _TromLoadingScreen(),
      );
    }

    // Onboarding not complete — listener above will redirect; show loading meanwhile.
    if (onboardingStatus.value == false) {
      return const Scaffold(
        backgroundColor: TromblColors.bg,
        body: _TromLoadingScreen(),
      );
    }

    // Restore done — always show the vibe picker so users confirm their vibe
    // each time they open the app. _pick() reuses any existing session.

    final city = ref.watch(cityProvider);
    final suggested = _timeDefaultVibe();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              const Text(
                "what's the\nvibe today?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TromblText.serif,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: TromblColors.text,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              // City chip
              GestureDetector(
                onTap: () => _showCityPicker(city),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: TromblColors.card,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('📍', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        city ?? 'set city',
                        style: const TextStyle(
                            color: TromblColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              _VibeCard(
                emoji: '⚡',
                title: 'fomo',
                sub: 'i want everything',
                accent: TromblColors.fomo,
                suggested: suggested == 'fomo',
                onTap: () => _pick('fomo'),
              ),
              const SizedBox(height: 14),
              _VibeCard(
                emoji: '🛌',
                title: 'jomo',
                sub: 'i want nothing',
                accent: TromblColors.jomo,
                suggested: suggested == 'jomo',
                onTap: () => _pick('jomo'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  /// Returns trom's time-appropriate vibe suggestion.
  /// Late night / early morning → jomo. Fri/Sat evening → fomo. Else: context-neutral fomo.
  static String _timeDefaultVibe() {
    final hour = DateTime.now().hour;
    final weekday = DateTime.now().weekday; // 1=Mon … 7=Sun
    if (hour >= 22 || hour < 10) return 'jomo';
    if ((weekday == 5 || weekday == 6) && hour >= 17) return 'fomo';
    return 'fomo';
  }

  void _showCityPicker(String? current) {
    final ctrl = TextEditingController(text: current ?? '');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
              const Text('where u at?',
                  style: TextStyle(
                      fontFamily: TromblText.serif,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: TromblColors.text)),
              const SizedBox(height: 6),
              const Text('helps trom pick smarter for ur area.',
                  style: TextStyle(
                      color: TromblColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style:
                    const TextStyle(color: TromblColors.text, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'mumbai, delhi, bangalore...',
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
                onSubmitted: (v) async {
                  final city = v.trim();
                  final nav = Navigator.of(context);
                  if (city.isNotEmpty) {
                    await ref.read(cityProvider.notifier).setCity(city);
                  }
                  if (mounted) nav.pop();
                },
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  final city = ctrl.text.trim();
                  final nav = Navigator.of(context);
                  if (city.isNotEmpty) {
                    await ref.read(cityProvider.notifier).setCity(city);
                  }
                  if (mounted) nav.pop();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: TromblColors.jomo,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('set →',
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
}

class _VibeCard extends StatelessWidget {
  const _VibeCard({
    required this.emoji,
    required this.title,
    required this.sub,
    required this.accent,
    required this.suggested,
    required this.onTap,
  });
  final String emoji, title, sub;
  final Color accent;
  final bool suggested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: TromblColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: suggested
                ? accent.withValues(alpha: 0.55)
                : accent.withValues(alpha: 0.35),
            width: suggested ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: accent,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  Text(sub,
                      style: const TextStyle(
                          color: TromblColors.textSub, fontSize: 13)),
                ],
              ),
            ),
            if (suggested)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'trom rn',
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: TromblText.sans,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading screen shown while session is being restored from DB ─────────────
// Replaces the pure-black blank so users know something is happening.

class _TromLoadingScreen extends StatefulWidget {
  const _TromLoadingScreen();

  @override
  State<_TromLoadingScreen> createState() => _TromLoadingScreenState();
}

class _TromLoadingScreenState extends State<_TromLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
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
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Opacity(
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
}
