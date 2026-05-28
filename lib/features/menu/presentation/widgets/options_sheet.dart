import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/trombl_theme.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/result.dart';
import '../../../vibe/providers/session_providers.dart';
import '../../data/categories.dart';
import '../../../response/presentation/response_screen.dart';

class OptionsSheet extends ConsumerWidget {
  const OptionsSheet({super.key, required this.category, required this.vibe});
  final MenuCategory category;
  final String vibe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = TromblColors.accentFor(vibe);

    return Container(
      decoration: const BoxDecoration(
        color: TromblColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: TromblColors.textMuted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(category.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Text(
                category.label,
                style: TextStyle(
                  fontFamily: TromblText.serif,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'pick one.',
            style: TextStyle(color: TromblColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...category.options.map((opt) => _OptionRow(
            option: opt,
            vibe: vibe,
            onTap: () => _onPick(context, ref, opt),
          )),
        ],
      ),
    );
  }

  Future<void> _onPick(BuildContext context, WidgetRef ref, MenuOption opt) async {
    final session = ref.read(activeSessionProvider);
    if (session == null) return;

    Navigator.of(context).pop();

    final result = await ref.read(sessionRepositoryProvider).addPick(
      sessionId: session.id,
      categoryId: category.id,
      optionId: opt.id,
      label: opt.label,
      tag: opt.tag,
    );

    if (!context.mounted) return;

    switch (result) {
      case Success(:final data):
        context.push('/response', extra: ResponseArgs(
          pick: data,
          vibe: vibe,
          optionLabel: opt.label,
          action: opt.action,
          actionData: opt.actionData,
        ));
      case Failure(:final error):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option, required this.vibe, required this.onTap});
  final MenuOption option;
  final String vibe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: TromblColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option.label,
                style: const TextStyle(
                  color: TromblColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (option.action != ActionType.none)
              Text(
                _actionIcon(option.action),
                style: const TextStyle(fontSize: 14),
              ),
          ],
        ),
      ),
    );
  }

  String _actionIcon(ActionType action) => switch (action) {
    ActionType.zomato => '🍴',
    ActionType.bookmyshow => '🎟',
    ActionType.whatsapp => '💬',
    ActionType.dnd => '📵',
    ActionType.none => '',
  };
}
