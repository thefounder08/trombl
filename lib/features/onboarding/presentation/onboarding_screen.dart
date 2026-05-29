import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/trombl_theme.dart';

/// Three-slide intro shown once to new users after the name-setup screen.
/// Teaches fomo vs jomo before the first vibe pick.
///
/// Navigates to /vibe when done. Skip is available on every slide.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  static const _slides = [_Slide0(), _Slide1(), _Slide2()];

  void _next() {
    HapticFeedback.lightImpact();
    if (_page < _slides.length - 1) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _done();
    }
  }

  void _done() {
    HapticFeedback.heavyImpact();
    context.go('/vibe');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: TromblColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Skip — top right, hidden on last slide
            if (!isLast)
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: _done,
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(0, 16, 24, 0),
                    child: Text(
                      'skip',
                      style: TextStyle(
                        fontFamily: TromblText.sans,
                        color: TromblColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 32),

            // Slides
            Expanded(
              child: PageView(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _page = i),
                children: _slides,
              ),
            ),

            // Dots + CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 16, 26, 32),
              child: Column(
                children: [
                  // Page dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? TromblColors.text
                              : TromblColors.textMuted,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  // CTA button
                  GestureDetector(
                    onTap: _next,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      decoration: BoxDecoration(
                        gradient: isLast
                            ? const LinearGradient(
                                colors: [TromblColors.fomo, TromblColors.jomo])
                            : null,
                        color: isLast ? null : TromblColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: isLast
                            ? null
                            : Border.all(color: TromblColors.border),
                      ),
                      child: Text(
                        isLast ? "ok let's go →" : 'next →',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: TromblText.sans,
                          color: isLast
                              ? const Color(0xFF090909)
                              : TromblColors.textSub,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Slides ───────────────────────────────────────────────────────────────────

class _Slide0 extends StatelessWidget {
  const _Slide0();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🔥', style: TextStyle(fontSize: 52)),
          SizedBox(height: 24),
          Text(
            "u never know what to do.\ntrom does.",
            style: TextStyle(
              fontFamily: TromblText.serif,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: TromblColors.text,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 16),
          Text(
            "trom is ur chaotic bestie.\nchaotic, warm, and very opinionated\nabout what u should do tonight.",
            style: TextStyle(
              fontFamily: TromblText.sans,
              fontSize: 15,
              color: TromblColors.textSub,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide1 extends StatelessWidget {
  const _Slide1();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "fomo or jomo?",
            style: TextStyle(
              fontFamily: TromblText.serif,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: TromblColors.text,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 16),
          Text(
            "every day starts with one honest question.",
            style: TextStyle(
              fontFamily: TromblText.sans,
              fontSize: 15,
              color: TromblColors.textSub,
              height: 1.5,
            ),
          ),
          SizedBox(height: 32),
          // Fomo card preview
          _VibePreviewCard(
            emoji: '⚡',
            vibe: 'fomo',
            label: 'fomo',
            sub: 'i want everything',
            accent: TromblColors.fomo,
          ),
          SizedBox(height: 12),
          // Jomo card preview
          _VibePreviewCard(
            emoji: '🛌',
            vibe: 'jomo',
            label: 'jomo',
            sub: 'i want nothing',
            accent: TromblColors.jomo,
          ),
        ],
      ),
    );
  }
}

class _Slide2 extends StatelessWidget {
  const _Slide2();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('✨', style: TextStyle(fontSize: 52)),
          SizedBox(height: 24),
          Text(
            "trom picks a side.\nu just go live it.",
            style: TextStyle(
              fontFamily: TromblText.serif,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: TromblColors.text,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 16),
          Text(
            "pick ur vibe. trom shows u what to do.\ntap an option. trom reacts.\n\nno planning. no overthinking.\njust go.",
            style: TextStyle(
              fontFamily: TromblText.sans,
              fontSize: 15,
              color: TromblColors.textSub,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Vibe preview card (used on slide 1) ─────────────────────────────────────

class _VibePreviewCard extends StatelessWidget {
  const _VibePreviewCard({
    required this.emoji,
    required this.vibe,
    required this.label,
    required this.sub,
    required this.accent,
  });
  final String emoji, vibe, label, sub;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TromblColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: TromblText.sans,
                  color: accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(
                  fontFamily: TromblText.sans,
                  color: TromblColors.textSub,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
