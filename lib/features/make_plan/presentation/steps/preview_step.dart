import 'package:flutter/material.dart';

import '../../../../core/theme/trombl_theme.dart';
import '../../../plan/domain/plan_phrasing.dart';
import '../../domain/make_plan_draft.dart';

/// Step 6 — read-only recap before Create Plan.
class PreviewStep extends StatelessWidget {
  const PreviewStep({
    super.key,
    required this.draft,
    required this.accent,
  });
  final MakePlanDraft draft;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final title = draft.option != null
        ? planPhrasing(draft.option!.label)
        : 'ur plan';
    final timeLabel = formatStartTime(draft.startsAt);

    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: [
        const Text(
          'locked in? 🔥',
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
          'one last look before it goes out.',
          style: TextStyle(color: TromblColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TromblColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: TromblText.serif,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              const SizedBox(height: 14),
              _Row(icon: '⏰', label: timeLabel ?? 'no time set yet'),
              _Row(icon: '📍', label: draft.location ?? 'no location yet'),
              _Row(
                icon: '👥',
                label: draft.invited.isEmpty
                    ? "no one invited yet — u can still share the link"
                    : '${draft.invited.length} ${draft.invited.length == 1 ? 'person' : 'people'} invited',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label});
  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: TromblColors.textSub,
                fontSize: 13,
                fontFamily: TromblText.sans,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
