import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/trombl_theme.dart';
import '../../../shared/models/models.dart';
import '../../vibe/providers/session_providers.dart';
import '../providers/checkin_providers.dart';
import 'day_summary_screen.dart';

class CheckinScreen extends ConsumerWidget {
  const CheckinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final vibe = session?.vibe ?? 'fomo';
    final accent = TromblColors.accentFor(vibe);
    final picksAsync = ref.watch(checkinPicksProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.go('/menu'),
                child: const Text(
                  '← back',
                  style: TextStyle(color: TromblColors.textMuted, fontSize: 13),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'how did it go?',
                style: TextStyle(
                  fontFamily: TromblText.serif,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'tap what you actually did.',
                style: TextStyle(color: TromblColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: picksAsync.when(
                  loading: () => const Center(
                    child: Text(
                      'loading ur day...',
                      style: TextStyle(
                          color: TromblColors.textMuted, fontSize: 14),
                    ),
                  ),
                  error: (_, __) => const Center(
                    child: Text(
                      'trom lost track. try again.',
                      style: TextStyle(
                          color: TromblColors.textMuted, fontSize: 14),
                    ),
                  ),
                  data: (picks) => picks.isEmpty
                      ? const Center(
                          child: Text(
                            "you haven't picked anything today yet.",
                            style: TextStyle(
                                color: TromblColors.textMuted, fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          itemCount: picks.length,
                          itemBuilder: (_, i) => _PickRow(
                            pick: picks[i],
                            accent: accent,
                            onToggle: (done) => ref
                                .read(checkinPicksProvider.notifier)
                                .toggle(picks[i].id, done),
                          ),
                        ),
                ),
              ),
              picksAsync.maybeWhen(
                data: (picks) => picks.isEmpty
                    ? const SizedBox.shrink()
                    : _WrapButton(vibe: vibe, picks: picks, accent: accent),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.pick,
    required this.accent,
    required this.onToggle,
  });
  final Pick pick;
  final Color accent;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onToggle(!pick.done);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: pick.done
              ? accent.withValues(alpha:0.08)
              : TromblColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: pick.done ? accent.withValues(alpha:0.3) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: pick.done ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: pick.done ? accent : TromblColors.textMuted,
                  width: 1.5,
                ),
              ),
              child: pick.done
                  ? const Icon(Icons.check, size: 13, color: Color(0xFF0B0B0D))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                pick.label,
                style: TextStyle(
                  color: pick.done ? TromblColors.text : TromblColors.textSub,
                  fontSize: 15,
                  fontWeight:
                      pick.done ? FontWeight.w600 : FontWeight.w500,
                  decoration:
                      pick.done ? TextDecoration.none : TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WrapButton extends ConsumerWidget {
  const _WrapButton({
    required this.vibe,
    required this.picks,
    required this.accent,
  });
  final String vibe;
  final List<Pick> picks;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = picks.where((p) => p.done).length;
    final total = picks.length;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.heavyImpact();
        await ref.read(checkinPicksProvider.notifier).wrapDay();
        if (!context.mounted) return;
        context.pushReplacement('/summary', extra: DaySummaryScreenArgs(
          vibe: vibe,
          total: total,
          done: done,
          doneLabels: picks.where((p) => p.done).map((p) => p.label).toList(),
        ));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: vibe == 'fomo'
                ? [TromblColors.fomo, TromblColors.fomo.withValues(alpha:0.7)]
                : [TromblColors.jomo, TromblColors.jomo.withValues(alpha:0.7)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          done == 0
              ? 'wrap the day anyway →'
              : 'wrap the day ($done/$total done) →',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF0B0B0D),
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
