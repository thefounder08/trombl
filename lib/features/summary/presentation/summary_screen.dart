import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/trombl_theme.dart';
import '../../menu/providers/menu_providers.dart';
import '../../vibe/providers/session_providers.dart';

/// Args passed via GoRouter extra.
class SummaryArgs {
  const SummaryArgs({required this.done, required this.total});
  final int done;
  final int total;
}

/// End-of-session verdict. Hardcoded reactive headline — no LLM, no wait.
class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key, required this.args});
  final SummaryArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),

              // Reactive headline
              Text(
                _headline(args.done, args.total),
                style: const TextStyle(
                  fontFamily: TromblText.serif,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: TromblColors.text,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 12),

              // Sub-line with actual numbers
              Text(
                '${args.done} of ${args.total} picked things actually done.',
                style: const TextStyle(
                  fontFamily: TromblText.sans,
                  fontSize: 14,
                  color: TromblColors.textSub,
                  height: 1.4,
                ),
              ),

              const Spacer(),

              // "done for now" — stay in today's session
              _PrimaryButton(
                label: 'done for now',
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.go('/menu');
                },
              ),
              const SizedBox(height: 12),

              // "new vibe" — clear session, go pick again
              _SecondaryButton(
                label: 'new vibe',
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(activeSessionProvider.notifier).clear();
                  ref.read(activePickProvider.notifier).clear();
                  context.go('/vibe');
                },
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  static String _headline(int done, int total) {
    if (done == 0) return "u picked $total things. did zero. iconic.";
    if (done == total) return "u actually did everything. who are u.";
    return "$done/$total. trom respects the effort.";
  }
}

// ─── Buttons ─────────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [TromblColors.fomo, TromblColors.jomo],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: TromblText.sans,
            color: Color(0xFF090909),
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: TromblColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TromblColors.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: TromblText.sans,
            color: TromblColors.textSub,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
