import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/trombl_theme.dart';
import '../../../menu/domain/menu_models.dart';

/// Step 2 — pick a specific option within the chosen category.
class ChooseOptionsStep extends StatelessWidget {
  const ChooseOptionsStep({
    super.key,
    required this.category,
    required this.accent,
    required this.onSelect,
  });
  final MenuCategory category;
  final Color accent;
  final ValueChanged<MenuOption> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: [
        Text(
          '${category.emoji} ${category.title}',
          style: const TextStyle(
            fontFamily: TromblText.serif,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: TromblColors.text,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'locked in on the details.',
          style: TextStyle(color: TromblColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        ...category.options.where((o) => !o.isComingSoon).map((opt) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(opt);
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
                      Expanded(
                        child: Text(
                          opt.label,
                          style: const TextStyle(
                            color: TromblColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: TromblText.sans,
                          ),
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
