import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/trombl_theme.dart';
import '../../../shared/models/models.dart';
import '../../vibe/providers/session_providers.dart';

// Loads wrapped sessions + their picks as a list of (Session, List<Pick>) pairs
final _historyProvider = FutureProvider.autoDispose<List<(Session, List<Pick>)>>((ref) async {
  final repo = ref.watch(sessionRepositoryProvider);
  // Fetch last 30 days of sessions, only wrapped ones
  final allSessions = await repo.recentSessions(days: 30);
  final wrapped = allSessions.where((s) => s.wrappedAt != null).toList();
  if (wrapped.isEmpty) return [];
  final picks = await repo.picksForSessions(wrapped.map((s) => s.id).toList());
  final picksBySession = <String, List<Pick>>{};
  for (final p in picks) {
    picksBySession.putIfAbsent(p.sessionId, () => []).add(p);
  }
  return wrapped.map((s) => (s, picksBySession[s.id] ?? <Pick>[])).toList();
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_historyProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go('/home'),
                    child: const Text('← back',
                        style: TextStyle(
                            color: TromblColors.textMuted, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 20, 22, 4),
              child: Text(
                'UR HISTORY',
                style: TextStyle(
                  color: TromblColors.textMuted,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Stats row
            historyAsync.maybeWhen(
              data: (history) {
                if (history.isEmpty) return const SizedBox.shrink();
                final fomo = history.where((e) => e.$1.vibe == 'fomo').length;
                final jomo = history.length - fomo;
                final allPicks =
                    history.expand((e) => e.$2).toList();
                final doneRate = allPicks.isEmpty
                    ? 0
                    : (allPicks.where((p) => p.done).length * 100 ~/
                        allPicks.length);
                return Padding(
                  padding:
                      const EdgeInsets.fromLTRB(22, 12, 22, 0),
                  child: Row(
                    children: [
                      _StatChip(
                          label: '${history.length} days',
                          color: TromblColors.textSub),
                      const SizedBox(width: 8),
                      if (fomo > 0)
                        _StatChip(
                            label: '$fomo ⚡',
                            color: TromblColors.fomo),
                      if (fomo > 0) const SizedBox(width: 8),
                      if (jomo > 0)
                        _StatChip(
                            label: '$jomo 🛌',
                            color: TromblColors.jomo),
                      if (allPicks.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _StatChip(
                            label: '$doneRate% done',
                            color: TromblColors.textSub),
                      ],
                    ],
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: historyAsync.when(
                loading: () => const Center(
                  child: Text('one sec...',
                      style: TextStyle(
                          color: TromblColors.textMuted, fontSize: 13)),
                ),
                error: (_, __) => const Center(
                  child: Text("couldn't load ur history.",
                      style: TextStyle(
                          color: TromblColors.textMuted, fontSize: 13)),
                ),
                data: (history) => history.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            "no wrapped days yet.\nwrap ur first day to start tracking.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: TromblColors.textMuted,
                                fontSize: 14,
                                height: 1.5),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: history.length,
                        itemBuilder: (_, i) {
                          final (session, picks) = history[i];
                          return _DayCard(session: session, picks: picks);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.session, required this.picks});
  final Session session;
  final List<Pick> picks;

  @override
  Widget build(BuildContext context) {
    final accent = TromblColors.accentFor(session.vibe);
    final date = session.startedAt;
    final dateStr = date != null
        ? _formatDate(date)
        : 'unknown day';
    final doneCount = picks.where((p) => p.done).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: TromblColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Text(
                  session.vibe == 'fomo' ? '⚡' : '🛌',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateStr,
                    style: const TextStyle(
                      color: TromblColors.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (picks.isNotEmpty)
                  Text(
                    '$doneCount/${picks.length} done',
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (picks.isNotEmpty) ...[
            const Divider(height: 1, color: TromblColors.border),
            ...picks.map((p) => _PickLine(pick: p, accent: accent)),
          ] else
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'nothing picked this day.',
                style: TextStyle(
                    color: TromblColors.textMuted, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    if (diff < 7) return '$diff days ago';
    final months = ['jan','feb','mar','apr','may','jun',
                    'jul','aug','sep','oct','nov','dec'];
    return '${months[d.month - 1]} ${d.day}';
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PickLine extends StatelessWidget {
  const _PickLine({required this.pick, required this.accent});
  final Pick pick;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          Icon(
            pick.done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: pick.done ? accent : TromblColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pick.label,
              style: TextStyle(
                color: pick.done ? TromblColors.text : TromblColors.textSub,
                fontSize: 13,
                fontWeight: pick.done ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
