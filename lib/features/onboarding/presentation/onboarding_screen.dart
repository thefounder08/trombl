import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/trombl_theme.dart';
import '../../vibe/providers/session_providers.dart';

// ─── Screen definitions ───────────────────────────────────────────────────────

class _ScreenDef {
  const _ScreenDef({
    required this.emoji,
    required this.question,
    required this.sub,
    required this.options,
    required this.multiSelect,
  });
  final String emoji;
  final String question;
  final String sub;
  final List<String> options;
  final bool multiSelect;
}

const _screens = [
  _ScreenDef(
    emoji: '🎯',
    question: "what are you\nhere for?",
    sub: "pick everything that feels right",
    options: ['things to do', 'productivity', 'fitness', 'social life', 'explore city', 'surprise me'],
    multiSelect: true,
  ),
  _ScreenDef(
    emoji: '✨',
    question: "your vibe?",
    sub: "be honest, trom doesn't judge",
    options: ['builder', 'social', 'explorer', 'cozy', 'mix'],
    multiSelect: false,
  ),
  _ScreenDef(
    emoji: '📅',
    question: "what's your\nschedule?",
    sub: "helps trom pick the right time to push u",
    options: ['student', '9-5', 'freelancer', 'shifts'],
    multiSelect: false,
  ),
  _ScreenDef(
    emoji: '🌤',
    question: "weekends?",
    sub: "no wrong answer",
    options: ['stay home', 'go out', 'depends'],
    multiSelect: false,
  ),
  _ScreenDef(
    emoji: '🔥',
    question: "what do you want\nmore of?",
    sub: "this shapes everything trom suggests",
    options: ['friends', 'fitness', 'money', 'creativity', 'balance', 'memories'],
    multiSelect: true,
  ),
];

// ─── Provider for the onboarding completion check ─────────────────────────────

final onboardingCompletedProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = ref.read(supabaseProvider).auth.currentUser;
  if (user == null) return true;
  final profile = await ref.read(sessionRepositoryProvider).getProfile();
  return profile?.onboardingCompleted ?? false;
});

// ─── Main screen ─────────────────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;
  bool _saving = false;

  // Answers stored as lists (single-select screens store one item)
  final List<List<String>> _answers = List.generate(_screens.length, (_) => []);

  @override
  void initState() {
    super.initState();
    ref.read(analyticsRepositoryProvider).trackOnboardingStarted();
  }

  List<String> get _current => _answers[_page];
  _ScreenDef get _def => _screens[_page];

  void _toggleOption(String option) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_def.multiSelect) {
        if (_current.contains(option)) {
          _current.remove(option);
        } else {
          _current.add(option);
        }
      } else {
        _current
          ..clear()
          ..add(option);
      }
    });
  }

  bool get _canProceed => _current.isNotEmpty;

  void _next() {
    if (!_canProceed) return;
    HapticFeedback.lightImpact();
    if (_page < _screens.length - 1) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    HapticFeedback.heavyImpact();

    try {
      await ref.read(sessionRepositoryProvider).saveOnboardingData(
            goals: _answers[0],
            archetype: _answers[1].firstOrNull ?? '',
            scheduleType: _answers[2].firstOrNull ?? '',
            weekendPref: _answers[3].firstOrNull ?? '',
            wantsMore: _answers[4],
          );
    } catch (_) {
      // Non-fatal — let user proceed even if save fails
    }

    ref.read(analyticsRepositoryProvider).trackOnboardingCompleted();
    if (mounted) context.go('/tutorial');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _screens.length - 1;

    return Scaffold(
      backgroundColor: TromblColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: progress dots + skip ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  // Progress dots
                  Row(
                    children: List.generate(_screens.length, (i) {
                      final done = i < _page;
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        width: active ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: done
                              ? TromblColors.jomo.withValues(alpha: 0.5)
                              : active
                                  ? TromblColors.text
                                  : TromblColors.textMuted,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  if (!isLast)
                    GestureDetector(
                      onTap: _finish,
                      child: const Text(
                        'skip all',
                        style: TextStyle(
                          color: TromblColors.textMuted,
                          fontSize: 13,
                          fontFamily: TromblText.sans,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Page view ────────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _screens.length,
                itemBuilder: (_, i) => _OnboardingPage(
                  def: _screens[i],
                  selected: _answers[i],
                  onToggle: i == _page ? _toggleOption : (_) {},
                ),
              ),
            ),

            // ── CTA ───────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: GestureDetector(
                onTap: _canProceed && !_saving ? _next : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  decoration: BoxDecoration(
                    gradient: _canProceed && !_saving
                        ? const LinearGradient(
                            colors: [TromblColors.fomo, TromblColors.jomo])
                        : null,
                    color: _canProceed && !_saving ? null : TromblColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: _canProceed
                        ? null
                        : Border.all(color: TromblColors.border),
                  ),
                  child: Text(
                    _saving
                        ? 'saving...'
                        : isLast
                            ? "let's go →"
                            : 'next →',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TromblText.sans,
                      color: _canProceed && !_saving
                          ? const Color(0xFF090909)
                          : TromblColors.textMuted,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Single onboarding page ───────────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.def,
    required this.selected,
    required this.onToggle,
  });
  final _ScreenDef def;
  final List<String> selected;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(def.emoji, style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 18),
          Text(
            def.question,
            style: const TextStyle(
              fontFamily: TromblText.serif,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: TromblColors.text,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            def.sub,
            style: const TextStyle(
              fontFamily: TromblText.sans,
              fontSize: 13,
              color: TromblColors.textMuted,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: def.options.map((opt) {
              final sel = selected.contains(opt);
              return GestureDetector(
                onTap: () => onToggle(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: sel
                        ? TromblColors.jomo.withValues(alpha: 0.15)
                        : TromblColors.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: sel
                          ? TromblColors.jomo.withValues(alpha: 0.55)
                          : TromblColors.border,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontFamily: TromblText.sans,
                      color: sel ? TromblColors.jomo : TromblColors.textSub,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
