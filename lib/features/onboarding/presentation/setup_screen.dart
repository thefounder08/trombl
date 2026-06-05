import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/trombl_theme.dart';
import '../../vibe/providers/session_providers.dart';

const _lifestyleOptions = [
  'student',
  'working 9-5',
  'freelance',
  'creative',
  'entrepreneur',
  'just vibing',
];

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _nameCtrl = TextEditingController();
  int _step = 1;
  String? _lifestyle;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _step = 2);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    await ref.read(sessionRepositoryProvider).updateProfile(
          displayName: name,
          lifestyle: _lifestyle,
        );
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
          child: _step == 1 ? _buildStep1() : _buildStep2(),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
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
            hintStyle:
                const TextStyle(color: TromblColors.textMuted, fontSize: 18),
            filled: true,
            fillColor: TromblColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          onSubmitted: (_) => _nextStep(),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _nextStep,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [TromblColors.fomo, TromblColors.jomo]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'next →',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF090909),
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => context.go('/onboarding'),
          child: const Center(
            child: Text(
              'skip for now',
              style: TextStyle(color: TromblColors.textMuted, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        const Text('👀', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 20),
        const Text(
          "what's ur\nsituation?",
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
          'trom picks better when it gets u.',
          style: TextStyle(color: TromblColors.textMuted, fontSize: 13),
        ),
        const Spacer(),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _lifestyleOptions.map((opt) {
            final selected = _lifestyle == opt;
            return GestureDetector(
              onTap: () => setState(() => _lifestyle = selected ? null : opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? TromblColors.fomo.withValues(alpha: 0.15)
                      : TromblColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? TromblColors.fomo.withValues(alpha: 0.5)
                        : TromblColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    color: selected ? TromblColors.fomo : TromblColors.textSub,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                    fontFamily: TromblText.sans,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const Spacer(),
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
              _loading ? 'saving...' : "let's go →",
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
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _loading ? null : _save,
          child: const Center(
            child: Text(
              'skip this',
              style: TextStyle(color: TromblColors.textMuted, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}
