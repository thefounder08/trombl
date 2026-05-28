import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/trombl_theme.dart';
import '../../vibe/providers/session_providers.dart';

/// "trom's read on you" — backed by real session history.
final recentSessionsProvider = FutureProvider.autoDispose((ref) async {
  return ref.watch(sessionRepositoryProvider).recentSessions();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recentSessionsProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.go('/menu'),
                child: const Text('← menu',
                    style: TextStyle(color: TromblColors.textSub)),
              ),
              const SizedBox(height: 18),
              const Text('TROM\'S READ ON YOU',
                  style: TextStyle(
                      color: TromblColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Expanded(
                child: async.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(color: TromblColors.jomo)),
                  error: (_, __) => const Text("couldn't load ur read. try again?",
                      style: TextStyle(color: TromblColors.textSub)),
                  data: (sessions) {
                    if (sessions.isEmpty) {
                      return const Text(
                        "trom's still figuring u out.\npick a few things and patterns show up here.",
                        style: TextStyle(
                            fontFamily: TromblText.serif,
                            fontSize: 24,
                            color: TromblColors.text,
                            height: 1.25),
                      );
                    }
                    final jomo = sessions.where((s) => s.vibe == 'jomo').length;
                    final fomo = sessions.length - jomo;
                    final headline = jomo > fomo
                        ? 'you run hot, then you ghost.'
                        : fomo > jomo
                            ? "you don't sit still, do you."
                            : "trom can't pin you down.";
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(headline,
                            style: const TextStyle(
                                fontFamily: TromblText.serif,
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                                color: TromblColors.text,
                                height: 1.22)),
                        const SizedBox(height: 16),
                        Text('last ${sessions.length} days · $fomo fomo, $jomo jomo',
                            style: const TextStyle(color: TromblColors.textSub)),
                      ],
                    );
                  },
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await ref.read(supabaseProvider).auth.signOut();
                  ref.read(activeSessionProvider.notifier).clear();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('start over',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: TromblColors.textSub)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
