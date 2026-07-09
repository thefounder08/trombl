import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/trombl_theme.dart';
import '../../vibe/providers/session_providers.dart';
import '../domain/checkin_item.dart';
import '../providers/checkin_providers.dart';
import '../../summary/presentation/summary_screen.dart';

class CheckinScreen extends ConsumerWidget {
  const CheckinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final vibe = session?.vibe ?? 'fomo';
    final accent = TromblColors.accentFor(vibe);
    final itemsAsync = ref.watch(checkinPicksProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.go('/home'),
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
                'tap what u actually did.',
                style: TextStyle(color: TromblColors.textMuted, fontSize: 13),
              ),
              itemsAsync.maybeWhen(
                data: (items) => items.isEmpty
                    ? const SizedBox.shrink()
                    : _ProgressLine(
                        done: items.where((i) => i.done).length,
                        total: items.length,
                        accent: accent,
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: itemsAsync.when(
                  loading: () => const Center(
                    child: Text(
                      'loading ur day...',
                      style: TextStyle(
                          color: TromblColors.textMuted, fontSize: 14),
                    ),
                  ),
                  error: (_, _) => const Center(
                    child: Text(
                      'trom lost track. try again.',
                      style: TextStyle(
                          color: TromblColors.textMuted, fontSize: 14),
                    ),
                  ),
                  data: (items) => items.isEmpty
                      ? const Center(
                          child: Text(
                            "u haven't picked anything today yet.",
                            style: TextStyle(
                                color: TromblColors.textMuted, fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (_, i) => _CheckinItemRow(
                            item: items[i],
                            accent: accent,
                            onToggle: (done) => ref
                                .read(checkinPicksProvider.notifier)
                                .toggle(items[i].id, done),
                          ),
                        ),
                ),
              ),
              itemsAsync.maybeWhen(
                data: (items) => items.isEmpty
                    ? const SizedBox.shrink()
                    : _WrapButton(vibe: vibe, items: items, accent: accent),
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

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.done,
    required this.total,
    required this.accent,
  });
  final int done;
  final int total;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        '$done/$total done so far',
        style: TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _CheckinItemRow extends StatelessWidget {
  const _CheckinItemRow({
    required this.item,
    required this.accent,
    required this.onToggle,
  });
  final CheckinItem item;
  final Color accent;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final done = item.done;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onToggle(!done);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: done ? accent.withValues(alpha: 0.08) : TromblColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: done ? accent.withValues(alpha: 0.3) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: done ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: done ? accent : TromblColors.textMuted,
                  width: 1.5,
                ),
              ),
              child: done
                  ? const Icon(Icons.check, size: 13, color: Color(0xFF0B0B0D))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  color: done ? TromblColors.text : TromblColors.textSub,
                  fontSize: 15,
                  fontWeight: done ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (item is CheckinAiPickItem) ...[
              const SizedBox(width: 6),
              Text('✨',
                  style: TextStyle(fontSize: 11, color: accent.withValues(alpha: 0.7))),
            ],
            const SizedBox(width: 8),
            Text(
              done ? '✅ done' : '❌ skipped',
              style: TextStyle(
                color: done ? accent : TromblColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
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
    required this.items,
    required this.accent,
  });
  final String vibe;
  final List<CheckinItem> items;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = items.where((i) => i.done).length;
    final total = items.length;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.heavyImpact();
        ref.read(analyticsRepositoryProvider).trackCheckinStarted(pickCount: total);
        await ref.read(checkinPicksProvider.notifier).wrapDay();
        ref.read(analyticsRepositoryProvider).trackCheckinCompleted(
          totalPicks: total, donePicks: done);
        ref.read(analyticsRepositoryProvider)
            .trackSummaryViewed(totalPicks: total, donePicks: done);
        if (!context.mounted) return;
        // Navigate to the spec-compliant reactive summary screen.
        context.pushReplacement('/summary', extra: SummaryArgs(
          done: done,
          total: total,
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
