import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/trombl_theme.dart';
import '../../vibe/providers/session_providers.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    await ref.read(sessionRepositoryProvider).updateProfile(displayName: name);
    if (!mounted) return;

    final pendingToken = ref.read(pendingPlanTokenProvider);
    if (pendingToken != null) {
      ref.read(pendingPlanTokenProvider.notifier).state = null;
      context.go('/p/$pendingToken');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              28, 0, 28, MediaQuery.of(context).viewInsets.bottom + 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Text('🔥', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 20),
              const Text(
                'what should\ntrom call u?',
                style: TextStyle(
                  fontFamily: TromblText.serif,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: TromblColors.text,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'just a name. nothing weird.',
                style: TextStyle(color: TromblColors.textMuted, fontSize: 13),
              ),
              const Spacer(),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                    color: TromblColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'ur name',
                  hintStyle: const TextStyle(
                      color: TromblColors.textMuted, fontSize: 18),
                  filled: true,
                  fillColor: TromblColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _loading ? null : _save,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: _loading
                        ? null
                        : const LinearGradient(
                            colors: [TromblColors.fomo, TromblColors.jomo]),
                    color: _loading ? TromblColors.card : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _loading ? 'saving...' : 'next →',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _loading
                          ? TromblColors.textSub
                          : const Color(0xFF090909),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
