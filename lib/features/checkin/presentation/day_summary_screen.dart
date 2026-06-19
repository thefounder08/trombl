import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/trombl_theme.dart';
import '../../vibe/providers/session_providers.dart';
import '../providers/checkin_providers.dart';

class DaySummaryScreenArgs {
  const DaySummaryScreenArgs({
    required this.vibe,
    required this.total,
    required this.done,
    required this.doneLabels,
  });
  final String vibe;
  final int total;
  final int done;
  final List<String> doneLabels;
}

class DaySummaryScreen extends ConsumerWidget {
  const DaySummaryScreen({super.key, required this.args});
  final DaySummaryScreenArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = TromblColors.accentFor(args.vibe);
    final summaryAsync = ref.watch(daySummaryProvider((
      vibe: args.vibe,
      total: args.total,
      done: args.done,
      doneLabels: args.doneLabels,
    )));

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                args.vibe == 'fomo' ? '⚡ fomo day' : '🛌 jomo day',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              _StatsRow(done: args.done, total: args.total, accent: accent),
              const SizedBox(height: 24),
              summaryAsync.when(
                loading: () => _TypingIndicator(),
                error: (_, __) => const Text(
                  "trom lost the plot. but u lived it, so that's enough.",
                  style: TextStyle(
                    fontFamily: TromblText.serif,
                    fontSize: 26,
                    color: TromblColors.text,
                    height: 1.25,
                  ),
                ),
                data: (text) => Text(
                  text,
                  style: const TextStyle(
                    fontFamily: TromblText.serif,
                    fontSize: 26,
                    color: TromblColors.text,
                    height: 1.25,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  ref.read(activeSessionProvider.notifier).clear();
                  context.go('/vibe');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [TromblColors.fomo, TromblColors.jomo]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'start a new day →',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF090909),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends ConsumerWidget {
  const _StatsRow({
    required this.done,
    required this.total,
    required this.accent,
  });
  final int done;
  final int total;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider).value ?? 0;
    return Row(
      children: [
        _Stat(value: '$done', label: 'done', accent: accent),
        const SizedBox(width: 20),
        _Stat(value: '$total', label: 'picked', accent: TromblColors.textSub),
        if (streak > 1) ...[
          const SizedBox(width: 20),
          _Stat(
            value: '🔥$streak',
            label: 'day streak',
            accent: TromblColors.fomo,
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.accent});
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: TromblText.serif,
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: TromblColors.textMuted,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: const Text(
          'trom is processing ur day...',
          style: TextStyle(
            fontFamily: TromblText.serif,
            fontSize: 26,
            color: TromblColors.textMuted,
            height: 1.25,
          ),
        ),
      ),
    );
  }
}
