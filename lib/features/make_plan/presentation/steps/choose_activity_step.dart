import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/trombl_theme.dart';
import '../../../menu/domain/menu_data.dart';
import '../../../menu/domain/menu_models.dart';

/// Step 1 — pick a category. Reuses TromblMenu's existing vibe-scoped
/// category data (same source as Home's category grid / the menu screen),
/// just with simple selection instead of resolving an action.
class ChooseActivityStep extends StatelessWidget {
  const ChooseActivityStep({
    super.key,
    required this.vibe,
    required this.accent,
    required this.onSelect,
  });
  final String vibe;
  final Color accent;
  final ValueChanged<MenuCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    final categories = TromblMenu.core(vibe);
    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: [
        const Text(
          "what's the vibe? 👀",
          style: TextStyle(
            fontFamily: TromblText.serif,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: TromblColors.text,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'pick a category to build the plan around.',
          style: TextStyle(color: TromblColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        ...categories.map((cat) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(cat);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(
                    color: TromblColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: TromblColors.border),
                  ),
                  child: Row(
                    children: [
                      Text(cat.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.title,
                              style: const TextStyle(
                                color: TromblColors.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                fontFamily: TromblText.sans,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              cat.sub,
                              style: const TextStyle(
                                color: TromblColors.textMuted,
                                fontSize: 12,
                                fontFamily: TromblText.sans,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text('→', style: TextStyle(color: accent, fontSize: 15)),
                    ],
                  ),
                ),
              ),
            )),
      ],
    );
  }
}
