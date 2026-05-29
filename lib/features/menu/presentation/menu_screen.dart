import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/trombl_theme.dart';
import '../../vibe/providers/session_providers.dart';
import '../../checkin/providers/checkin_providers.dart';
import '../data/categories.dart';
import 'widgets/options_sheet.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session   = ref.watch(activeSessionProvider);
    final vibe      = session?.vibe ?? 'fomo';
    final accent    = TromblColors.accentFor(vibe);
    final categories = Categories.forVibe(vibe);
    final newDrop   = Categories.newDropFor(vibe);
    final pickCount = ref.watch(todayPickCountProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Vibe chip + pick counter
                  Row(
                    children: [
                      _VibeChip(
                        vibe: vibe,
                        accent: accent,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          ref.read(activeSessionProvider.notifier).switchVibe();
                        },
                      ),
                      if (pickCount > 0) ...[
                        const SizedBox(width: 8),
                        _PickBadge(count: pickCount, accent: accent),
                      ],
                    ],
                  ),
                  // Nav actions
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push('/checkin');
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: Text(
                            'wrap day',
                            style: TextStyle(
                              color: TromblColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: () => context.push('/profile'),
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: TromblColors.card,
                            shape: BoxShape.circle,
                            border: Border.all(color: TromblColors.border),
                          ),
                          child: const Center(
                            child: Text('○', style: TextStyle(color: TromblColors.textSub, fontSize: 14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Greeting ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
              child: Text(
                _greeting(vibe),
                style: const TextStyle(
                  fontFamily: TromblText.serif,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: TromblColors.text,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            // ── Category grid + NEW DROP ──────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  // 2-col grid of core 4 categories
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.05,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: categories.map((cat) => _CategoryCard(
                      category: cat,
                      vibe: vibe,
                    )).toList(),
                  ),
                  const SizedBox(height: 10),
                  // NEW DROP — full-width card
                  _NewDropCard(category: newDrop, vibe: vibe),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting(String vibe) {
    final h = DateTime.now().hour;
    if (vibe == 'fomo') {
      if (h < 12) return 'ok go.\nwhat first?';
      if (h < 17) return 'afternoon mode.\npick something.';
      if (h < 21) return "evening's yours.\nmake it count.";
      return "night's still young.\nwhat's it?";
    } else {
      if (h < 12) return 'slow morning.\nwhat calls to you?';
      if (h < 17) return 'cozy hours.\npick your vibe.';
      if (h < 21) return "evening in.\nwhat's the move?";
      return 'night in.\npure jomo.';
    }
  }
}

// ─── Vibe chip ────────────────────────────────────────────────────────────────

class _VibeChip extends StatelessWidget {
  const _VibeChip({required this.vibe, required this.accent, required this.onTap});
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
              style: TextStyle(
                color: accent.withValues(alpha: 0.45),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pick badge ───────────────────────────────────────────────────────────────

class _PickBadge extends StatelessWidget {
  const _PickBadge({required this.count, required this.accent});
  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count picked',
        style: TextStyle(
          color: accent,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFamily: TromblText.sans,
        ),
      ),
    );
  }
}

// ─── Category card ────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.vibe});
  final MenuCategory category;
  final String vibe;

  @override
  Widget build(BuildContext context) {
    final accent = TromblColors.accentFor(vibe);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _openSheet(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: TromblColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.14)),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category.emoji, style: const TextStyle(fontSize: 30)),
            const Spacer(),
            Text(
              category.title,
              style: const TextStyle(
                color: TromblColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: TromblText.sans,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              category.sub,
              style: const TextStyle(
                color: TromblColors.textSub,
                fontSize: 11,
                fontFamily: TromblText.sans,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => OptionsSheet(category: category, vibe: vibe),
    );
  }
}

// ─── NEW DROP card ────────────────────────────────────────────────────────────

class _NewDropCard extends StatelessWidget {
  const _NewDropCard({required this.category, required this.vibe});
  final MenuCategory category;
  final String vibe;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => OptionsSheet(category: category, vibe: vibe),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: TromblColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: TromblColors.newDrop.withValues(alpha: 0.28)),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            // Left: icon + titles
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: TromblColors.newGlow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: TromblColors.newDrop.withValues(alpha: 0.35)),
                    ),
                    child: const Text(
                      '⚡ new this week',
                      style: TextStyle(
                        color: TromblColors.newDrop,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        fontFamily: TromblText.sans,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(category.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          category.title,
                          style: const TextStyle(
                            color: TromblColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: TromblText.sans,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.sub,
                    style: const TextStyle(
                      color: TromblColors.textSub,
                      fontSize: 12,
                      fontFamily: TromblText.sans,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            // Right: arrow
            const SizedBox(width: 12),
            Text(
              '→',
              style: TextStyle(
                color: TromblColors.newDrop.withValues(alpha: 0.7),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
