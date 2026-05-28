import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/trombl_theme.dart';
import '../../vibe/providers/session_providers.dart';
import '../data/categories.dart';
import 'widgets/options_sheet.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final vibe = session?.vibe ?? 'fomo';
    final accent = TromblColors.accentFor(vibe);
    final categories = Categories.forVibe(vibe);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    vibe == 'fomo' ? '⚡ fomo' : '🛌 jomo',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      fontSize: 12,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: const Text(
                      '○',
                      style: TextStyle(color: TromblColors.textSub, fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
              child: Text(
                vibe == 'fomo'
                    ? 'ok go. what first?'
                    : "what's calling to you?",
                style: const TextStyle(
                  fontFamily: TromblText.serif,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: TromblColors.text,
                  height: 1.2,
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: categories.length,
                itemBuilder: (context, i) => _CategoryCard(
                  category: categories[i],
                  vibe: vibe,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.vibe});
  final MenuCategory category;
  final String vibe;

  @override
  Widget build(BuildContext context) {
    final accent = TromblColors.accentFor(vibe);

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => OptionsSheet(category: category, vibe: vibe),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: TromblColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withOpacity(0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(category.emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 10),
            Text(
              category.label,
              style: const TextStyle(
                color: TromblColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
