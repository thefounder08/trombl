import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/trombl_theme.dart';
import '../providers/session_providers.dart';

/// The heart of the app: fomo vs jomo. Picking creates a real session row.
class VibeScreen extends ConsumerWidget {
  const VibeScreen({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref, String vibe) async {
    HapticFeedback.heavyImpact();
    final city = ref.read(cityProvider);
    final err = await ref.read(activeSessionProvider.notifier).start(vibe, city: city);
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

    final city = ref.watch(cityProvider);

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
                onTap: () => _showCityPicker(context, ref, city),
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
                      const Text('📍',
                          style: TextStyle(fontSize: 12)),
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

  void _showCityPicker(BuildContext context, WidgetRef ref, String? current) {
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
              const Text('where are you?',
                  style: TextStyle(
                      fontFamily: TromblText.serif,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: TromblColors.text)),
              const SizedBox(height: 6),
              const Text('helps trom give more relevant picks.',
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
                  if (city.isNotEmpty) {
                    await ref.read(cityProvider.notifier).setCity(city);
                  }
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  final city = ctrl.text.trim();
                  if (city.isNotEmpty) {
                    await ref.read(cityProvider.notifier).setCity(city);
                  }
                  if (context.mounted) Navigator.of(context).pop();
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
