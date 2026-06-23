import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers.dart';
import '../../../core/theme/trombl_theme.dart';

const _kTutorialSeenKey = 'trombl_tutorial_seen';

class _Slide {
  const _Slide({
    required this.emoji,
    required this.title,
    required this.body,
  });
  final String emoji;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    emoji: '⚡🛌',
    title: 'fomo or jomo?',
    body:
        'fomo = going for it.\njomo = protecting ur peace.\n\nno wrong answer. trom just needs to know where ur head\'s at.',
  ),
  _Slide(
    emoji: '🎯',
    title: 'trombl picks for u',
    body:
        'scroll the options. tap one that hits.\ntrom clocks it, gives u a push, and tells u what to do first.\n\nfor when ur brain just can\'t decide.',
  ),
  _Slide(
    emoji: '🔥',
    title: 'trom is kinda ur bestie',
    body:
        'she\'s chaotic but she means well.\nshe\'ll roast u a little. give u the first step.\nmaybe even draft a squad text.\n\nu good? she\'s got u.',
  ),
];

class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  final _ctrl = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    ref.read(analyticsRepositoryProvider).trackTutorialStarted();
  }

  Future<void> _finish({required bool skipped}) async {
    HapticFeedback.heavyImpact();
    final repo = ref.read(analyticsRepositoryProvider);
    skipped ? repo.trackTutorialSkipped(atSlide: _page) : repo.trackTutorialCompleted();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTutorialSeenKey, true);
    if (mounted) context.go('/vibe');
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_page < _slides.length - 1) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish(skipped: false);
    }
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
            // Skip
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isLast)
                    GestureDetector(
                      onTap: () => _finish(skipped: true),
                      child: const Text(
                        'skip',
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

            // Slides
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _page = i);
                },
                itemCount: _slides.length,
                itemBuilder: (_, i) => _TutorialSlide(slide: _slides[i]),
              ),
            ),

            // Dots + CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
              child: Column(
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
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
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _next,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [TromblColors.fomo, TromblColors.jomo],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isLast ? "let's go →" : 'next →',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: TromblText.sans,
                          color: Color(0xFF090909),
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

class _TutorialSlide extends StatelessWidget {
  const _TutorialSlide({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(slide.emoji, style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 20),
          Text(
            slide.title,
            style: const TextStyle(
              fontFamily: TromblText.serif,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: TromblColors.text,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            slide.body,
            style: const TextStyle(
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
