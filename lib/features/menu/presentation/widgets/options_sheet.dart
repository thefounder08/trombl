import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/trombl_theme.dart';
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
    final accent = category.isNewDrop
        ? TromblColors.newDrop
        : TromblColors.accentFor(vibe);

    return Container(
      decoration: const BoxDecoration(
        color: TromblColors.cardLit,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(22, 14, 22,
          MediaQuery.of(context).padding.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: TromblColors.borderMid,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Category header
          Row(
            children: [
              Text(category.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: TextStyle(
                        fontFamily: TromblText.serif,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: accent,
                        height: 1.15,
                      ),
                    ),
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
              if (category.isNewDrop)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: TromblColors.newGlow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: TromblColors.newDrop.withValues(alpha: 0.35)),
                  ),
                  child: const Text(
                    'new',
                    style: TextStyle(
                      color: TromblColors.newDrop,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      fontFamily: TromblText.sans,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'pick one.',
            style: TextStyle(
              color: TromblColors.textMuted,
              fontSize: 12,
              fontFamily: TromblText.sans,
            ),
          ),
          const SizedBox(height: 16),

          // Options list
          ...category.options.map((opt) => _OptionRow(
            option: opt,
            vibe: vibe,
            accent: accent,
            onTap: opt.isComingSoon
                ? () {
                    HapticFeedback.selectionClick();
                    // Gentle toast for coming soon
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('dropping soon 👀'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                : () => _onPick(context, ref, opt),
          )),
        ],
      ),
    );
  }

  Future<void> _onPick(BuildContext context, WidgetRef ref, MenuOption opt) async {
    HapticFeedback.mediumImpact();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
    }
  }
}

// ─── Option row ───────────────────────────────────────────────────────────────

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.vibe,
    required this.accent,
    required this.onTap,
  });
  final MenuOption option;
  final String vibe;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDisabled = option.isComingSoon;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isDisabled ? 0.38 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: TromblColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDisabled
                  ? Colors.transparent
                  : accent.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  option.label,
                  style: TextStyle(
                    color: isDisabled ? TromblColors.textSub : TromblColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: TromblText.sans,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _TagChip(action: option.action, tag: option.tag, accent: accent),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tag chip ─────────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  const _TagChip({required this.action, required this.tag, required this.accent});
  final ActionType action;
  final String tag;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (action == ActionType.comingSoon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: TromblColors.border,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'soon',
          style: TextStyle(
            color: TromblColors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            fontFamily: TromblText.sans,
          ),
        ),
      );
    }

    if (action == ActionType.none) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Text(
        '⚡ $tag',
        style: TextStyle(
          color: accent,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          fontFamily: TromblText.sans,
        ),
      ),
    );
  }
}
