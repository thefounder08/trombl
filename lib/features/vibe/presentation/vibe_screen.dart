import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/trombl_theme.dart';
import '../providers/session_providers.dart';

/// The heart of the app: fomo vs jomo. Picking creates a real session row.
class VibeScreen extends ConsumerWidget {
  const VibeScreen({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref, String vibe) async {
    final err = await ref.read(activeSessionProvider.notifier).start(vibe);
    if (err != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
      return;
    }
    if (context.mounted) context.go('/menu');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Auto-redirect when today's session is restored from DB
    ref.listen(activeSessionProvider, (_, session) {
      if (session != null && context.mounted) context.go('/menu');
    });

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
              const Spacer(),
              _VibeCard(
                emoji: '⚡',
                title: 'fomo',
                sub: 'i want everything',
                accent: TromblColors.fomo,
                onTap: () => _pick(context, ref, 'fomo'),
              ),
              const SizedBox(height: 14),
              _VibeCard(
                emoji: '🛌',
                title: 'jomo',
                sub: 'i want nothing',
                accent: TromblColors.jomo,
                onTap: () => _pick(context, ref, 'jomo'),
              ),
              const Spacer(),
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
    required this.onTap,
  });
  final String emoji, title, sub;
  final Color accent;
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
          border: Border.all(color: accent.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: accent, fontSize: 20, fontWeight: FontWeight.w800)),
                Text(sub,
                    style: const TextStyle(
                        color: TromblColors.textSub, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
